# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"
require "concurrent"

WebhookReceived = Class.new(RubyEventStore::Event)

class UniqueWebhooksTest < Minitest::Test
  DELIVERY_ID = "evt_1Pq2Rs3T"
  STREAM = "Webhook$#{DELIVERY_ID}"

  def setup
    @event_store = RubyEventStore::Client.new
  end

  # The payment provider retries a webhook when it does not get a response in
  # time. Two requests with the same delivery id arrive at the same moment.
  # Each one checks whether the webhook was already saved, finds nothing, and
  # saves it. The webhook must be saved only once.
  def test_the_same_webhook_delivered_twice_at_the_same_moment_is_saved_once
    both_have_checked = Concurrent::CountDownLatch.new(2)

    outcomes = 2.times.map do
      Thread.new do
        already_saved = @event_store.read.stream(STREAM).count.positive?
        both_have_checked.count_down
        both_have_checked.wait(1)
        next :duplicate if already_saved

        # No expected_version given, so RubyEventStore defaults to :any.
        @event_store.publish(webhook_received, stream_name: STREAM)
        :saved
      rescue RubyEventStore::WrongExpectedEventVersion => e
        e.class
      end
    end.map(&:value)

    assert_equal 1, @event_store.read.stream(STREAM).count,
                 "webhook #{DELIVERY_ID} saved #{@event_store.read.stream(STREAM).count} times, outcomes #{outcomes.inspect}"
    assert_equal [:saved, RubyEventStore::WrongExpectedEventVersion].sort_by(&:to_s), outcomes.sort_by(&:to_s)
  end

  private

  def webhook_received
    WebhookReceived.new(data: { delivery_id: DELIVERY_ID, type: "payment.succeeded", amount_cents: 4_200 })
  end
end
