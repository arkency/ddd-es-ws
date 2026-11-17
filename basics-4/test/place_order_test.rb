# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "active_job"
require "ruby_event_store"
require "ruby_event_store/active_record"
require "rails_event_store"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:event_store_events) do |t|
    t.references :event, null: false, type: :string, limit: 36, index: { unique: true }
    t.string :event_type, null: false, index: true
    t.binary :metadata
    t.binary :data, null: false
    t.datetime :created_at, null: false, precision: 6, index: true
    t.datetime :valid_at, null: true, precision: 6, index: true
  end

  create_table(:event_store_events_in_streams) do |t|
    t.string :stream, null: false
    t.integer :position, null: true
    t.references :event, null: false, type: :string, limit: 36, index: true
    t.datetime :created_at, null: false, precision: 6, index: true
    t.index %i[stream position], unique: true
    t.index %i[stream event_id], unique: true
  end

  create_table(:orders, id: :string) do |t|
    t.integer :amount_cents, null: false
  end
end

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(nil)

class PlaceOrderTest < Minitest::Test
  OrderPlaced = Class.new(RubyEventStore::Event)
  PaymentDeclined = Class.new(StandardError)

  class Order < ActiveRecord::Base
    self.table_name = "orders"
  end

  class SendOrderConfirmation < ActiveJob::Base
    def perform(event)
    end
  end

  class PaymentGateway
    LIMIT_CENTS = 10_000

    def charge(order_id:, amount_cents:)
      raise PaymentDeclined, "card declined for #{order_id}" if amount_cents > LIMIT_CENTS
    end
  end

  class PlaceOrder
    def initialize(event_store, payment_gateway)
      @event_store = event_store
      @payment_gateway = payment_gateway
    end

    def call(order_id:, amount_cents:)
      ActiveRecord::Base.transaction do
        Order.create!(id: order_id, amount_cents: amount_cents)
        @event_store.publish(
          OrderPlaced.new(data: { order_id: order_id, amount_cents: amount_cents }),
          stream_name: "Order$#{order_id}"
        )
        @payment_gateway.charge(order_id: order_id, amount_cents: amount_cents)
      end
    end
  end

  def setup
    Order.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events_in_streams")
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events")
    enqueued_jobs.clear

    @event_store = RubyEventStore::Client.new(
      repository: RubyEventStore::ActiveRecord::EventRepository.new(serializer: RubyEventStore::Serializers::YAML),
      message_broker: RubyEventStore::Broker.new(
        dispatcher: RubyEventStore::ImmediateDispatcher.new(
          scheduler: RailsEventStore::ActiveJobScheduler.new(serializer: RubyEventStore::Serializers::YAML)
        )
      )
    )
    @event_store.subscribe(SendOrderConfirmation, to: [OrderPlaced])
    @place_order = PlaceOrder.new(@event_store, PaymentGateway.new)
  end

  def test_placed_order_sends_a_confirmation
    @place_order.call(order_id: "ord-1", amount_cents: 2_500)

    assert Order.exists?("ord-1")
    assert_equal 1, @event_store.read.stream("Order$ord-1").count
    assert_equal [SendOrderConfirmation], enqueued_jobs.map { |job| job["job_class"].constantize }
  end

  def test_declined_order_sends_no_confirmation
    assert_raises(PaymentDeclined) { @place_order.call(order_id: "ord-2", amount_cents: 50_000) }

    refute Order.exists?("ord-2")
    assert_equal 0, @event_store.read.stream("Order$ord-2").count
    assert_equal [], enqueued_jobs.map { |job| job["job_class"] },
                 "order ord-2 and its OrderPlaced event were rolled back, " \
                 "but the customer still gets a confirmation email for it"
  end

  private

  def enqueued_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
  end
end
