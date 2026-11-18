# frozen_string_literal: true

module Invoicing
  module Integrations
    # ANTI-CORRUPTION LAYER over Payments.
    # Payments' opaque `reference` is what Invoicing calls an order_ref; a received payment is a settlement.
    # May arrive before or after the invoice exists -- settlements are matched when displaying.
    class PaymentsAcl < IntegrationJob
      def call(event)
        Commands.record_settlement(order_ref: event.data[:reference], amount_cents: event.data[:amount_cents])
      end
    end
  end
end
