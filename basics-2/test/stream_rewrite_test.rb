# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"
require "ruby_event_store/active_record"
require "active_record"
require "concurrent"

ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "ddd_es_ws_test", pool: 5)
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  drop_table :event_store_events_in_streams, if_exists: true
  drop_table :event_store_events, if_exists: true

  create_table(:event_store_events, id: :bigserial) do |t|
    t.references :event, null: false, type: :uuid, index: { unique: true }
    t.string :event_type, null: false, index: true
    t.binary :metadata
    t.binary :data, null: false
    t.datetime :created_at, null: false, precision: 6, index: true
    t.datetime :valid_at, null: true, precision: 6, index: true
  end

  create_table(:event_store_events_in_streams, id: :bigserial) do |t|
    t.string :stream, null: false
    t.integer :position, null: true
    t.references :event, null: false, type: :uuid, index: true
    t.datetime :created_at, null: false, precision: 6, index: true
    t.index %i[stream position], unique: true
    t.index %i[stream event_id], unique: true
  end

  add_foreign_key :event_store_events_in_streams, :event_store_events, column: :event_id, primary_key: :event_id
end

class StreamRewriteTest < Minitest::Test
  PriceChanged = Class.new(RubyEventStore::Event)
  ConnectionLost = Class.new(StandardError)

  OLD_STREAM = "Price$sku-42"
  NEW_STREAM = "ProductPrice$sku-42"

  def setup
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events_in_streams")
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events")

    @event_store = RubyEventStore::Client.new(
      repository: RubyEventStore::ActiveRecord::EventRepository.new(serializer: RubyEventStore::Serializers::YAML)
    )
    [100, 120, 90, 110, 95].each do |price_cents|
      @event_store.publish(PriceChanged.new(data: { sku: "sku-42", price_cents: price_cents }), stream_name: OLD_STREAM)
    end
    @history = @event_store.read.stream(OLD_STREAM).map(&:event_id)
  end

  def test_rewrite_leaves_only_the_new_stream
    event_ids = @event_store.read.stream(OLD_STREAM).map(&:event_id)
    @event_store.link(event_ids, stream_name: NEW_STREAM)

    assert_equal @history, @event_store.read.stream(NEW_STREAM).map(&:event_id)
    assert_equal 5, @event_store.read.count
    assert_equal [NEW_STREAM], streams, "expected only #{NEW_STREAM}, found #{streams.inspect}"
  end

  def test_rewrite_that_fails_halfway_leaves_the_old_stream_untouched
    assert_raises(ConnectionLost) do
      event_ids = @event_store.read.stream(OLD_STREAM).map(&:event_id)
      @event_store.delete_stream(OLD_STREAM)
      event_ids.each_with_index do |event_id, index|
        raise ConnectionLost if index == 2

        @event_store.link(event_id, stream_name: NEW_STREAM)
      end
    end

    assert_equal 5, @event_store.read.count
    assert_equal [OLD_STREAM], streams,
                 "old stream deleted and new one only half populated: " \
                 "#{OLD_STREAM} has #{@event_store.read.stream(OLD_STREAM).count} events, " \
                 "#{NEW_STREAM} has #{@event_store.read.stream(NEW_STREAM).count} of 5"
    assert_equal @history, @event_store.read.stream(OLD_STREAM).map(&:event_id)
  end

  def test_rewrite_keeps_a_price_change_made_by_production_meanwhile
    ids_read = Concurrent::CountDownLatch.new
    price_changed = Concurrent::CountDownLatch.new

    rewrite = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          event_ids = @event_store.read.stream(OLD_STREAM).map(&:event_id)
          ids_read.count_down
          price_changed.wait(5)
          @event_store.link(event_ids, stream_name: NEW_STREAM)
          @event_store.delete_stream(OLD_STREAM)
        end
      end
    end

    production = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ids_read.wait(5)
        production_changes_price_to(130)
        price_changed.count_down
      end
    end

    [rewrite, production].each(&:join)

    assert_equal 6, @event_store.read.count
    assert_equal [NEW_STREAM], streams
    assert_equal 130, current_price,
                 "projection shows #{current_price}: the production change is in no stream, " \
                 "#{NEW_STREAM} has #{@event_store.read.stream(NEW_STREAM).count} of 6 events"
  end

  private

  def production_changes_price_to(price_cents)
    @event_store.publish(PriceChanged.new(data: { sku: "sku-42", price_cents: price_cents }), stream_name: OLD_STREAM)
  end

  def current_price
    RubyEventStore::Projection
      .init(nil)
      .on(PriceChanged) { |_, event| event.data[:price_cents] }
      .call(@event_store.read.stream(NEW_STREAM))
  end

  def streams
    ActiveRecord::Base.connection.select_values("SELECT DISTINCT stream FROM event_store_events_in_streams")
  end
end
