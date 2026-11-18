# frozen_string_literal: true

module Reservations
  module RequestConferenceRoom
    class Handler
      def call(command)
        reservation_id = Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "agreement:#{command.agreement_ref}")
        return reservation_id if ReadModels::Reservation.exists?(reservation_id) # redelivered event

        room = ReadModels::ConferenceRoom.find_by(resource_id: command.resource_id)
        period = Availability::Public::Period.new(
          resource_id: command.resource_id, date: command.date,
          from_hour: command.from_hour, to_hour: command.to_hour,
        )
        booking = {
          id: reservation_id, resource_id: command.resource_id, resource_type: "conference_room",
          client: command.client, label: room&.label || command.resource_id, date: command.date,
          from_hour: command.from_hour, to_hour: command.to_hour,
          amount_cents: command.amount_cents, agreement_ref: command.agreement_ref,
        }

        ActiveRecord::Base.transaction do
          Integrations::AvailabilityConformist.block(period, reference: reservation_id)
          reservation = Internal::Bookings.record!(**booking)
          Internal::Bookings.publish(ReservationRequested.new(data: Internal::Bookings.data(reservation)))
        rescue Availability::Public::NotAvailable => e
          reservation = Internal::Bookings.record!(**booking.merge(status: "rejected: #{e.message}", amount_cents: 0))
          Internal::Bookings.publish(
            ReservationRejected.new(data: Internal::Bookings.data(reservation).merge(reason: e.message)),
          )
        end
        reservation_id
      end
    end
  end
end
