# frozen_string_literal: true

module Reservations
  module Settle
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          booking = ReadModels::Reservation.find(command.reservation_id)
          return if booking.status == "reserved" # redelivered payment event

          unless booking.status == "awaiting_payment"
            raise NotAwaitingPayment, "reservation #{command.reservation_id} is #{booking.status}"
          end
          unless command.paid_cents == booking.amount_cents
            raise AmountMismatch, "paid #{command.paid_cents}, expected #{booking.amount_cents}"
          end

          Integrations::AvailabilityConformist.block(
            Availability::Public::Period.new(
              resource_id: booking.resource_id, date: booking.date,
              from_hour: booking.from_hour, to_hour: booking.to_hour,
            ),
            reference: command.reservation_id,
          )
          booking.update!(status: "reserved")
          Internal::Bookings.publish(Public::ReservationConfirmed.new(data: Internal::Bookings.data(booking)))
        end
      end
    end
  end
end
