# frozen_string_literal: true

module Reservations
  module Integrations
    # ANTI-CORRUPTION LAYER over Payments.
    #
    # Payments is generic: payments with an opaque `reference`. We know that for our payments
    # the reference is a reservation id; anything else is not ours and is ignored.
    class PaymentsAcl < IntegrationJob
      def call(event)
        reservation_id = event.data[:reference]
        return unless ReadModels::Reservation.exists?(reservation_id)

        case event
        when Payments::Public::PaymentReceived
          Commands.settle(reservation_id: reservation_id, paid_cents: event.data[:amount_cents])
        when Payments::Public::PaymentTimedOut
          Commands.expire(reservation_id: reservation_id)
        end
      end
    end
  end
end
