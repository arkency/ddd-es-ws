# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"
require "ruby_event_store/sidekiq_scheduler"
require "sidekiq"
require "sidekiq/api"

REDIS_URL = "redis://127.0.0.1:6390/0"
REDIS_PID = spawn("redis-server", "--port", "6390", "--maxmemory", "3mb", "--maxmemory-policy", "noeviction",
                  "--save", "", "--appendonly", "no", out: File::NULL)
Minitest.after_run do
  Process.kill("TERM", REDIS_PID)
  Process.wait(REDIS_PID)
end

Sidekiq.configure_client do |config|
  config.redis = { url: REDIS_URL }
  config.logger.level = Logger::WARN
end

class SidekiqOverflowTest < Minitest::Test
  PriceChanged = Class.new(RubyEventStore::Event)

  LEGACY_PRICES = 600

  class SyncPriceToMarketplace
    include Sidekiq::Job

    CALLS = Concurrent::AtomicFixnum.new

    def perform(_event)
      sleep 0.05
      CALLS.increment
    end
  end

  class BackfillLegacyPrices
    def initialize(event_store)
      @event_store = event_store
    end

    def call(rows)
      rows.each do |row|
        @event_store.publish(PriceChanged.new(data: row), stream_name: "Price$#{row[:sku]}")
      end
    end
  end

  def setup
    wait_for_redis
    Sidekiq.redis(&:flushdb)
    SyncPriceToMarketplace::CALLS.value = 0

    @event_store = RubyEventStore::Client.new(
      message_broker: RubyEventStore::Broker.new(
        dispatcher: RubyEventStore::ImmediateDispatcher.new(
          scheduler: RubyEventStore::SidekiqScheduler.new(serializer: RubyEventStore::Serializers::YAML)
        )
      )
    )
    @event_store.subscribe(SyncPriceToMarketplace, to: [PriceChanged])

    @sidekiq = Sidekiq.configure_embed do |config|
      config.redis = { url: REDIS_URL }
      config.queues = %w[default]
      config.concurrency = 5
      config.logger.level = Logger::WARN
    end
    @sidekiq.run
  end

  def teardown
    Sidekiq.redis(&:flushdb)
    @sidekiq.stop
  end

  def test_backfill_does_not_exhaust_redis_memory
    rows = LEGACY_PRICES.times.map do |i|
      history = 240.times.map { |month| { month: month, price_cents: 1_000 + i + month } }
      { sku: "sku-#{i}", price_cents: 1_000 + i, history: history }
    end

    begin
      BackfillLegacyPrices.new(@event_store).call(rows)
    rescue RedisClient::CommandError => e
      flunk "backfill stopped after #{@event_store.read.count} of #{LEGACY_PRICES} prices, " \
            "Redis used #{redis_memory} of #{redis_maxmemory}: #{e.message}"
    end

    wait_until_jobs_done
    assert_equal LEGACY_PRICES, @event_store.read.count
    assert_equal LEGACY_PRICES, SyncPriceToMarketplace::CALLS.value
  end

  private

  def wait_for_redis
    Sidekiq.redis { |redis| redis.call("PING") }
  rescue RedisClient::CannotConnectError
    sleep 0.05
    retry
  end

  def wait_until_jobs_done
    deadline = Time.now + 60
    sleep 0.1 until SyncPriceToMarketplace::CALLS.value >= LEGACY_PRICES || Time.now > deadline
  end

  def redis_memory
    redis_info("used_memory_human")
  end

  def redis_maxmemory
    redis_info("maxmemory_human")
  end

  def redis_info(key)
    Sidekiq.redis { |redis| redis.call("INFO", "memory") }[/#{key}:(\S+)/, 1]
  end
end
