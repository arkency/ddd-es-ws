# frozen_string_literal: true

module Payments
  module RequestPayment
    class Handler
      def call(command)
        payment_id = SecureRandom.uuid
        Internal::Repository.with_payment(payment_id) do |payment|
          payment.request(reference: command.reference, payer: command.payer, amount_cents: command.amount_cents)
        end
        payment_id
      end
    end
  end
end
