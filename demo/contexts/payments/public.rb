# frozen_string_literal: true

module Payments
  module Public
    PaymentReceived = Class.new(RubyEventStore::Event) # payment_id, reference, payer, amount_cents
    PaymentTimedOut = Class.new(RubyEventStore::Event) # payment_id, reference
  end
end
