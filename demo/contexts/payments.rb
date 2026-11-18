# frozen_string_literal: true

# Payments: generic subdomain. Collects money for an opaque reference via the payment gateway.
# Context map: OHS/PL upstream of Reservations (ACL) and Invoicing (ACL). Knows nobody downstream.
#
# Events defined here are private. Events other contexts may use live in Payments::Public.
module Payments
  PaymentRequested = Class.new(RubyEventStore::Event) # payment_id, reference, payer, amount_cents

  def self.subscribe_internal(event_store)
    event_store.subscribe(
      ReadModels::Projection.new,
      to: [PaymentRequested, Public::PaymentReceived, Public::PaymentTimedOut],
    )
  end
end
