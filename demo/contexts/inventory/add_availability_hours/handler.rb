# frozen_string_literal: true

module Inventory
  module AddAvailabilityHours
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          resource = ReadModels::Resource.find(command.resource_id)
          resource.update!(opens_at_hour: command.opens_at_hour, closes_at_hour: command.closes_at_hour)
          Internal::Resources.publish(
            Public::ResourceHoursAdded.new(
              data: { resource_id: command.resource_id, resource_type: resource.resource_type,
                      opens_at_hour: command.opens_at_hour, closes_at_hour: command.closes_at_hour },
            ),
            command.resource_id,
          )
        end
      end
    end
  end
end
