# frozen_string_literal: true

module Reservations
  module Expire
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          booking = ReadModels::Reservation.find(command.reservation_id)
          return if booking.status == "expired" # redelivered timeout

          unless booking.status == "awaiting_payment"
            raise NotAwaitingPayment, "reservation #{command.reservation_id} is #{booking.status}"
          end

          Integrations::AvailabilityConformist.release(
            resource_id: booking.resource_id, reference: command.reservation_id,
          )
          booking.update!(status: "expired")
          Internal::Bookings.publish(ReservationExpired.new(data: { reservation_id: command.reservation_id }))
        end
      end
    end
  end
end
