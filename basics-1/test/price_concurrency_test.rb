# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"
require "concurrent"

PriceChanged = Class.new(RubyEventStore::Event)

class PriceConcurrencyTest < Minitest::Test
  SKU = "sku-42"
  STREAM = "Price$#{SKU}"

  def setup
    @event_store = RubyEventStore::Client.new
    @event_store.publish(price_changed(from: nil, to: 100), stream_name: STREAM)
  end

  def test_two_managers_change_the_price_at_the_same_moment
    both_have_read = Concurrent::CountDownLatch.new(2)

    outcomes = [120, 90].map do |new_price|
      Thread.new do
        seen = @event_store.read.stream(STREAM).last.data[:price_cents]
        both_have_read.count_down
        both_have_read.wait(1)

        @event_store.publish(price_changed(from: seen, to: new_price), stream_name: STREAM)
        :changed
      rescue RubyEventStore::WrongExpectedEventVersion => e
        e.class
      end
    end.map(&:value)

    history = @event_store.read.stream(STREAM).map { |e| [e.data[:previous_price_cents], e.data[:price_cents]] }

    assert_equal 1, outcomes.count(RubyEventStore::WrongExpectedEventVersion),
                 "lost update: both changes were accepted, history #{history.inspect}"
    history.each_cons(2) do |(_, before), (previous, _)|
      assert_equal before, previous, "a change was decided on a stale price, history #{history.inspect}"
    end
  end

  private

  def price_changed(from:, to:)
    PriceChanged.new(data: { sku: SKU, previous_price_cents: from, price_cents: to })
  end
end
