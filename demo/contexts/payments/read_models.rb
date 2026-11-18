# frozen_string_literal: true

module Payments
  module ReadModels
    class Payment < ActiveRecord::Base
      self.table_name = "payments_payments"
    end

    class Projection
      def call(event)
        data = event.data
        case event
        when PaymentRequested
          Payment.find_or_initialize_by(id: data[:payment_id])
                 .update!(reference: data[:reference], payer: data[:payer], amount_cents: data[:amount_cents], status: "pending")
        when Public::PaymentReceived
          Payment.find(data[:payment_id]).update!(status: "received")
        when Public::PaymentTimedOut
          Payment.find(data[:payment_id]).update!(status: "timed_out")
        end
      end
    end
  end
end
