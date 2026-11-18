# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "active_job"
require "ruby_event_store"
require "ruby_event_store/active_record"
require "rails_event_store"
require "rails"
require "solid_queue"
require "zeitwerk"

SOLID_QUEUE_ROOT = Gem.loaded_specs.fetch("solid_queue").full_gem_path

# Solid Queue ships its models in app/models, which a Rails app adds to the
# autoloader. There is no Rails application here, so register that directory.
Zeitwerk::Loader.new.tap do |loader|
  loader.push_dir(File.join(SOLID_QUEUE_ROOT, "app/models/solid_queue"), namespace: SolidQueue)
  loader.setup
end

# Normally done by Solid Queue::Engine and ActiveJob::Railtie initializers,
# which never run outside a Rails application.
ActiveJob::Base.include(ActiveJob::ConcurrencyControls) unless ActiveJob::Base.method_defined?(:concurrency_key)
ActiveJob::Base.include(ActiveJob::EnqueueAfterTransactionCommit) unless ActiveJob::Base.ancestors.include?(ActiveJob::EnqueueAfterTransactionCommit)
# Enqueue inside the surrounding transaction, so the immediate dispatcher writes
# the job row on the same connection that the event store and Order row use.
ActiveJob::Base.enqueue_after_transaction_commit = false

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

# Solid Queue's own tables, in the same (in-memory) database as the event store.
load File.join(SOLID_QUEUE_ROOT, "lib/generators/solid_queue/install/templates/db/queue_schema.rb")

ActiveJob::Base.queue_adapter = :solid_queue
ActiveJob::Base.logger = Logger.new(nil)

class PlaceOrderSolidQueueTest < Minitest::Test
  OrderPlaced = Class.new(RubyEventStore::Event)
  PaymentDeclined = Class.new(StandardError)

  class Order < ActiveRecord::Base
    self.table_name = "orders"
  end

  class SendOrderConfirmation < ActiveJob::Base
    def perform(payload)
    end
  end

  class PaymentGateway
    LIMIT_CENTS = 10_000

    attr_reader :confirmation_jobs_while_charging

    def charge(order_id:, amount_cents:)
      @confirmation_jobs_while_charging =
        SolidQueue::Job.where(class_name: SendOrderConfirmation.name).count
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
    SolidQueue::Job.delete_all
    SolidQueue::ReadyExecution.delete_all
    SolidQueue::ScheduledExecution.delete_all
    SolidQueue::BlockedExecution.delete_all
    SolidQueue::Semaphore.delete_all

    @event_store = RubyEventStore::Client.new(
      repository: RubyEventStore::ActiveRecord::EventRepository.new(serializer: RubyEventStore::Serializers::YAML),
      message_broker: RubyEventStore::Broker.new(
        dispatcher: RubyEventStore::ImmediateDispatcher.new(
          scheduler: RailsEventStore::ActiveJobScheduler.new(serializer: RubyEventStore::Serializers::YAML)
        )
      )
    )
    @event_store.subscribe(SendOrderConfirmation, to: [OrderPlaced])
    @gateway = PaymentGateway.new
    @place_order = PlaceOrder.new(@event_store, @gateway)
  end

  def test_placed_order_enqueues_a_confirmation_in_solid_queue
    @place_order.call(order_id: "ord-1", amount_cents: 2_500)

    assert Order.exists?("ord-1")
    assert_equal 1, @event_store.read.stream("Order$ord-1").count
    assert_equal 1, @gateway.confirmation_jobs_while_charging,
                 "the immediate dispatcher should have written the job inside the transaction"
    assert_equal 1, confirmation_jobs.count
    assert_equal 1, SolidQueue::ReadyExecution.where(job_id: confirmation_jobs.select(:id)).count
  end

  def test_declined_order_rolls_back_its_confirmation_job_with_the_event
    assert_raises(PaymentDeclined) { @place_order.call(order_id: "ord-2", amount_cents: 50_000) }

    refute Order.exists?("ord-2")
    assert_equal 0, @event_store.read.stream("Order$ord-2").count
    assert_equal 1, @gateway.confirmation_jobs_while_charging,
                 "precondition: the job row was visible inside the transaction"
    assert_equal 0, confirmation_jobs.count,
                 "the confirmation job row must be rolled back together with the OrderPlaced event"
    assert_equal 0, SolidQueue::ReadyExecution.count
  end

  def test_deferred_enqueue_never_writes_a_job_for_a_rolled_back_transaction
    SendOrderConfirmation.enqueue_after_transaction_commit = true

    assert_raises(PaymentDeclined) { @place_order.call(order_id: "ord-3", amount_cents: 50_000) }

    assert_equal 0, @gateway.confirmation_jobs_while_charging,
                 "with after-commit enqueueing nothing is written while the transaction is open"
    assert_equal 0, confirmation_jobs.count
  ensure
    SendOrderConfirmation.enqueue_after_transaction_commit = false
  end

  private

  def confirmation_jobs
    SolidQueue::Job.where(class_name: SendOrderConfirmation.name)
  end
end
