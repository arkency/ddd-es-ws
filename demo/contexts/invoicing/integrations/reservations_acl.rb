# frozen_string_literal: true

module Invoicing
  module Integrations
    # ANTI-CORRUPTION LAYER over Reservations.
    # A reservation becomes an "order" with a buyer and one invoice line.
    class ReservationsAcl < IntegrationJob
      def call(event)
        data = event.data
        Commands.generate_invoice(
          order_ref: data[:reservation_id],
          contract_ref: data[:agreement_ref],
          buyer_name: data[:client],
          description: "#{data[:label]}, #{data[:date]} #{data[:from_hour]}:00-#{data[:to_hour]}:00",
          net_cents: data[:amount_cents],
        )
      end
    end
  end
end
