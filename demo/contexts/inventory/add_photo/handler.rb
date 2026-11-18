# frozen_string_literal: true

module Inventory
  module AddPhoto
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          ReadModels::Resource.find(command.resource_id).increment!(:photos_count)
          Internal::Resources.publish(
            PhotoAdded.new(data: { resource_id: command.resource_id, url: command.url }), command.resource_id,
          )
        end
      end
    end
  end
end
