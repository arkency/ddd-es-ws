# frozen_string_literal: true

module Availability
  module ReadModels
    # Opening hours per resource, for "what hours does this resource have on this date?" queries.
    # The Resource aggregate keeps its own copy for the checks it makes.
    class Projection
      def call(event)
        case event
        when OpeningHoursRecorded
          Internal::OpeningHours.find_or_initialize_by(resource_id: event.data[:resource_id])
                                .update!(opens_at_hour: event.data[:opens_at_hour], closes_at_hour: event.data[:closes_at_hour])
        when OpeningHoursForgotten
          Internal::OpeningHours.where(resource_id: event.data[:resource_id]).delete_all
        end
      end
    end
  end
end
