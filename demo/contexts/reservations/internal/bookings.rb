# frozen_string_literal: true

module Reservations
  module Internal
    # Shared by Reservations' slices: the reservation row is process state, and every fact of
    # the process goes to the single "Reservations" stream.
    module Bookings
      extend self

      def record!(id:, resource_id:, resource_type:, client:, label:, date:, from_hour:, to_hour:,
                  amount_cents:, agreement_ref: nil, status: "awaiting_payment")
        ReadModels::Reservation.create!(
          id: id, resource_id: resource_id, resource_type: resource_type, client: client, label: label,
          date: date, from_hour: from_hour, to_hour: to_hour, amount_cents: amount_cents,
          agreement_ref: agreement_ref, status: status,
        )
      end

      def data(reservation)
        {
          reservation_id: reservation.id, resource_id: reservation.resource_id,
          resource_type: reservation.resource_type, client: reservation.client, label: reservation.label,
          date: reservation.date, from_hour: reservation.from_hour, to_hour: reservation.to_hour,
          amount_cents: reservation.amount_cents, agreement_ref: reservation.agreement_ref,
        }
      end

      def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "Reservations")
    end
  end
end
