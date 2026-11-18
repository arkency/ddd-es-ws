# frozen_string_literal: true

module Reservations
  module RegisterResource
    class Handler
      def call(command)
        model = ReadModels::Catalog.model_for(command.resource_type)
        return unless model

        resource = model.find_or_initialize_by(resource_id: command.resource_id)
        resource.withdrawn = false if resource.new_record?
        resource.update!(
          name: command.name,
          **(command.resource_type == "desk" ? { zone: command.zone } : { capacity: command.capacity }),
        )
      end
    end
  end
end
