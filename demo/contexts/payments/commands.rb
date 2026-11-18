# frozen_string_literal: true

module Payments
  module Commands
    extend self

    # Checkout: someone (here: the UI) asks to collect an amount for an opaque reference.
    def request_payment(reference:, payer:, amount_cents:)
      payment_id = SecureRandom.uuid
      with_payment(payment_id) { |payment| payment.request(reference: reference, payer: payer, amount_cents: Integer(amount_cents)) }
      payment_id
    end

    # Payment gateway callbacks (simulated by buttons in the UI).
    def gateway_confirmed(payment_id:)
      with_payment(payment_id, &:receive)
    end

    def gateway_timed_out(payment_id:)
      with_payment(payment_id, &:time_out)
    end

    private

    def with_payment(id, &)
      ActiveRecord::Base.transaction do
        AggregateRoot::Repository.new(Rails.configuration.event_store)
                                 .with_aggregate(Internal::Payment.new(id), "Payments::Payment$#{id}", &)
      end
    end
  end
end
