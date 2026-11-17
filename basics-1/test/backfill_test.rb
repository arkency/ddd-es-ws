# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"

class BackfillTest < Minitest::Test
  PriceChanged = Class.new(RubyEventStore::Event)

  COST_PER_CALL = 0.05
  LEGACY_PRICES = 1_000
  PRODUCTION_PRICES = 3_000_000

  class MarketplaceApi
    attr_reader :calls

    def initialize
      @calls = []
    end

    def update_price(sku:, price_cents:)
      @calls << { sku: sku, price_cents: price_cents }
    end

    def bill
      calls.size * COST_PER_CALL
    end
  end

  class SyncPriceToMarketplace
    def initialize(api)
      @api = api
    end

    def call(event)
      @api.update_price(sku: event.data[:sku], price_cents: event.data[:price_cents])
    end
  end

  def setup
    @api = MarketplaceApi.new
    @event_store = RubyEventStore::Client.new
    @event_store.subscribe(SyncPriceToMarketplace.new(@api), to: [PriceChanged])
  end

  def test_a_live_price_change_is_synced_to_the_marketplace
    @event_store.publish(price_changed(sku: "sku-1", price_cents: 1_999), stream_name: "Price$sku-1")

    assert_equal [{ sku: "sku-1", price_cents: 1_999 }], @api.calls
  end

  def test_backfilling_legacy_prices_does_not_call_the_marketplace
    legacy_prices = LEGACY_PRICES.times.map { |i| { sku: "sku-#{i}", price_cents: 1_000 + i } }

    legacy_prices.each do |row|
      @event_store.publish(price_changed(**row), stream_name: "Price$#{row[:sku]}")
    end

    assert_equal LEGACY_PRICES, @event_store.read.of_type(PriceChanged).count
    assert_equal [1_007], @event_store.read.stream("Price$sku-7").map { |e| e.data[:price_cents] }
    assert_equal 0, @api.calls.size,
                 "backfill called the marketplace #{@api.calls.size} times for $#{format('%.2f', @api.bill)}. " \
                 "With #{PRODUCTION_PRICES} production prices that is $#{format('%.2f', PRODUCTION_PRICES * COST_PER_CALL)}"
  end

  private

  def price_changed(sku:, price_cents:)
    PriceChanged.new(data: { sku: sku, price_cents: price_cents })
  end
end
