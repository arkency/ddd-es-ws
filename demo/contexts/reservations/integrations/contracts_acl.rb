# frozen_string_literal: true

module Reservations
  module Integrations
    # ANTI-CORRUPTION LAYER over Contracts.
    #
    # A signed agreement carries a lot: company, tax id, list price, discount...
    # For Reservations it is just "reserve this room for this client, at this time, for this amount".
    class ContractsAcl < IntegrationJob
      def call(event)
        data = event.data
        Commands.request_conference_room(
          agreement_ref: data[:agreement_id],
          client: data[:client_name],
          resource_id: data[:room_id],
          date: data[:date],
          from_hour: data[:from_hour],
          to_hour: data[:to_hour],
          amount_cents: data[:total_cents],
        )
      end
    end
  end
end
