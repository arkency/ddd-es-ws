# frozen_string_literal: true

module FacilityAccess
  module Integrations
    # ANTI-CORRUPTION LAYER over Reservations.
    # A reservation becomes an access pass: who (holder), where (zone), when (valid_on + hours).
    # Desks all live on the co-work floor; a conference room is its own zone.
    class ReservationsAcl < IntegrationJob
      def call(event)
        data = event.data
        zone = data[:resource_type] == "desk" ? "Co-work floor" : data[:label]
        Commands.grant_access(
          booking_ref: data[:reservation_id],
          holder: data[:client],
          zone: zone,
          valid_on: data[:date],
          from_hour: data[:from_hour],
          to_hour: data[:to_hour],
        )
      end
    end
  end
end
