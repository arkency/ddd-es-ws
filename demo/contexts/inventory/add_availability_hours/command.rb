# frozen_string_literal: true

module Inventory
  module AddAvailabilityHours
    Command = Data.define(:resource_id, :opens_at_hour, :closes_at_hour) do
      def initialize(resource_id:, opens_at_hour:, closes_at_hour:)
        opens, closes = Integer(opens_at_hour), Integer(closes_at_hour)
        unless (0...closes).cover?(opens) && closes <= 24
          raise ArgumentError, "availability hours must be within 0-24 and open before close"
        end

        super(resource_id: resource_id, opens_at_hour: opens, closes_at_hour: closes)
      end
    end
  end
end
