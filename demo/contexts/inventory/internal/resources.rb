# frozen_string_literal: true

module Inventory
  module Internal
    # Shared write path for the resource table and its per-resource stream.
    module Resources
      extend self

      def add(resource_type:, name:, zone: nil, capacity: nil)
        resource_id = SecureRandom.uuid_v7
        ActiveRecord::Base.transaction do
          ReadModels::Resource.create!(
            id: resource_id, resource_type: resource_type, name: name,
            zone: zone, capacity: capacity, status: "available",
          )
          publish(
            Public::ResourceAdded.new(
              data: { resource_id: resource_id, resource_type: resource_type,
                      name: name, zone: zone, capacity: capacity },
            ),
            resource_id,
          )
        end
        resource_id
      end

      def change_status(resource_id, status, event_class)
        ActiveRecord::Base.transaction do
          resource = ReadModels::Resource.find(resource_id)
          resource.update!(status: status)
          publish(event_class.new(data: { resource_id: resource_id, resource_type: resource.resource_type }), resource_id)
        end
      end

      def publish(event, resource_id)
        Rails.configuration.event_store.publish(event, stream_name: "Inventory::Resource$#{resource_id}")
      end
    end
  end
end
