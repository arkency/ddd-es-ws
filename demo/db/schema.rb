# frozen_string_literal: true

# Loaded on first boot and by bin/reset. One SQLite database, one table prefix per bounded context.
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :event_store_events, force: true do |t|
    t.references :event, null: false, type: :string, limit: 36, index: { unique: true }
    t.string :event_type, null: false, index: true
    t.binary :metadata
    t.binary :data, null: false
    t.datetime :created_at, null: false, precision: 6, index: true
    t.datetime :valid_at, null: true, precision: 6, index: true
  end

  create_table :event_store_events_in_streams, force: true do |t|
    t.string :stream, null: false
    t.integer :position, null: true
    t.references :event, null: false, type: :string, limit: 36, index: true
    t.datetime :created_at, null: false, precision: 6, index: true
    t.index %i[stream position], unique: true
    t.index %i[stream event_id], unique: true
  end

  # Presentation aid for the Scenarios page: one row per scripted run (its correlation id,
  # which step comes next, step results so later steps can use earlier ids, and what happened).
  create_table :scenario_runs, primary_key: :id, id: :string, force: true do |t|
    t.string :scenario_key, null: false, index: true
    t.string :correlation_id, null: false
    t.integer :next_step, null: false, default: 0
    t.json :results, null: false
    t.json :steps, null: false
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false
  end

  # Infrastructure for the presentation: which event crossed which edge of the context map and when.
  # enqueued_at set, handled_at nil = the event is in transit to the downstream context.
  create_table :integration_logs, force: true do |t|
    t.string :integration, null: false
    t.string :message, null: false
    t.string :event_id
    t.datetime :published_at, precision: 6
    t.datetime :enqueued_at, precision: 6
    t.datetime :handled_at, precision: 6
    t.string :tables
    t.index %i[integration event_id], unique: true
  end

  # External mailing system fake: every e-mail any context "sends".
  create_table :outbox_messages, force: true do |t|
    t.string :sender, null: false
    t.string :recipient, null: false
    t.string :subject, null: false
    t.datetime :created_at, null: false, precision: 6
  end

  create_table :inventory_resources, id: :string, force: true do |t|
    t.string :resource_type, null: false
    t.string :name, null: false
    t.string :zone
    t.integer :capacity
    t.string :status, null: false
    t.integer :photos_count, null: false, default: 0
    t.integer :opens_at_hour
    t.integer :closes_at_hour
  end

  create_table :pricing_resources, primary_key: :resource_id, id: :string, force: true do |t|
    t.string :resource_type, null: false
    t.string :name, null: false
    t.string :zone
    t.integer :capacity
    t.string :status, null: false
    t.integer :price_cents
    t.string :price_unit
  end

  create_table :availability_hours, primary_key: :resource_id, id: :string, force: true do |t|
    t.integer :opens_at_hour, null: false
    t.integer :closes_at_hour, null: false
  end

  # What Reservations knows about Inventory, one table per resource type. Built from Inventory's
  # generic ResourceAdded / ResourceRemoved events; the PricingAcl adds the tariff.
  create_table :reservations_desks, primary_key: :resource_id, id: :string, force: true do |t|
    t.string :name
    t.string :zone
    t.boolean :withdrawn, null: false, default: false
    t.integer :rate_cents
    t.string :rate_unit
  end

  create_table :reservations_conference_rooms, primary_key: :resource_id, id: :string, force: true do |t|
    t.string :name
    t.integer :capacity
    t.boolean :withdrawn, null: false, default: false
    t.integer :rate_cents
    t.string :rate_unit
  end

  # Process state, not an aggregate: one row per reservation, moved by Reservations' commands.
  create_table :reservations_reservations, id: :string, force: true do |t|
    t.string :resource_id, null: false, index: true
    t.string :resource_type, null: false
    t.string :client, null: false
    t.string :label, null: false
    t.date :date, null: false
    t.integer :from_hour, null: false
    t.integer :to_hour, null: false
    t.integer :amount_cents, null: false
    t.string :agreement_ref
    t.string :status, null: false
  end

  create_table :payments_payments, id: :string, force: true do |t|
    t.string :reference, null: false
    t.string :payer, null: false
    t.integer :amount_cents, null: false
    t.string :status, null: false
  end

  create_table :contracts_agreements, id: :string, force: true do |t|
    t.string :client_name, null: false
    t.string :company, null: false
    t.string :tax_id, null: false
    t.string :room_id, null: false
    t.date :date, null: false
    t.integer :from_hour, null: false
    t.integer :to_hour, null: false
    t.integer :price_cents
    t.integer :discount_percent, null: false, default: 0
    t.integer :total_cents
    t.string :document_id
    t.string :status, null: false
  end

  create_table :negotiations_negotiations, primary_key: :agreement_id, id: :string, force: true do |t|
    t.json :terms, null: false
    t.json :open_proposal
    t.json :history, null: false
    t.string :status, null: false
  end

  create_table :invoicing_billing_terms, primary_key: :contract_ref, id: :string, force: true do |t|
    t.string :buyer_name, null: false
    t.string :tax_id, null: false
    t.integer :payment_terms_days, null: false
  end

  create_table :invoicing_invoices, id: :string, force: true do |t|
    t.string :order_ref, null: false, index: { unique: true }
    t.string :number, null: false
    t.string :buyer_name, null: false
    t.string :tax_id
    t.string :description, null: false
    t.integer :net_cents, null: false
    t.integer :payment_terms_days, null: false
    t.string :status, null: false
  end

  create_table :invoicing_settlements, primary_key: :order_ref, id: :string, force: true do |t|
    t.integer :amount_cents, null: false
  end

  create_table :facility_access_passes, id: :string, force: true do |t|
    t.string :booking_ref, null: false, index: { unique: true }
    t.string :holder, null: false
    t.string :zone, null: false
    t.date :valid_on, null: false
    t.integer :from_hour, null: false
    t.integer :to_hour, null: false
    t.string :code, null: false, index: { unique: true }
    t.string :status, null: false
  end

  create_table :facility_access_scans, force: true do |t|
    t.string :code, null: false
    t.string :result, null: false
    t.datetime :scanned_at, null: false, precision: 6
  end
end
