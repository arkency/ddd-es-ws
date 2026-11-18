# frozen_string_literal: true

module Reservations
  module PreReserveDesk
    class Handler
      def call(command)
        desk = ReadModels::Desk.find_by(resource_id: command.resource_id)
        raise NotBookable, "desk #{command.resource_id} is unknown or withdrawn" if desk.nil? || desk.withdrawn
        raise NotBookable, "desk #{command.resource_id} has no tariff yet" unless desk.rate_cents

        period = Integrations::AvailabilityConformist.opening_hours(resource_id: command.resource_id, date: command.date)
        raise NotBookable, "Availability knows no opening hours for #{desk.label}" unless period

        reservation_id = SecureRandom.uuid
        ActiveRecord::Base.transaction do
          Integrations::AvailabilityConformist.temporarily_block(period, reference: reservation_id)
          reservation = Internal::Bookings.record!(
            id: reservation_id, resource_id: command.resource_id, resource_type: desk.resource_type,
            client: command.client, label: desk.label, date: command.date,
            from_hour: period.from_hour, to_hour: period.to_hour, amount_cents: desk.rate_cents,
          )
          Internal::Bookings.publish(ReservationRequested.new(data: Internal::Bookings.data(reservation)))
        end
        reservation_id
      end
    end
  end
end
