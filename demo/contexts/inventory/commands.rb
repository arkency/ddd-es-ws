# frozen_string_literal: true

module Inventory
  # Entry point used by the UI. Inventory is CRUD-ish: state in tables, events published alongside.
  #
  # Ids are UUIDv7: time-ordered, so they sort by creation and index well, while still being
  # globally unique. The commands below keep the UI's words (desk, conference room); everything
  # they publish is a generic *resource* event.
  module Commands
    extend self

    DESK = ReadModels::Resource::DESK
    CONFERENCE_ROOM = ReadModels::Resource::CONFERENCE_ROOM

    def add_desk(name:, zone:)
      add_resource(resource_type: DESK, name: name, zone: zone)
    end

    def add_conference_room(name:, capacity:)
      add_resource(resource_type: CONFERENCE_ROOM, name: name, capacity: Integer(capacity))
    end

    def add_photo(resource_id:, url:)
      transaction do
        ReadModels::Resource.find(resource_id).increment!(:photos_count)
        publish(PhotoAdded.new(data: { resource_id: resource_id, url: url }), resource_id)
      end
    end

    def add_availability_hours(resource_id:, opens_at_hour:, closes_at_hour:)
      opens, closes = hours(opens_at_hour, closes_at_hour)
      transaction do
        resource = ReadModels::Resource.find(resource_id)
        resource.update!(opens_at_hour: opens, closes_at_hour: closes)
        publish(
          Public::ResourceHoursAdded.new(
            data: { resource_id: resource_id, resource_type: resource.resource_type,
                    opens_at_hour: opens, closes_at_hour: closes },
          ),
          resource_id,
        )
      end
    end

    def take_resource_out_of_service(resource_id:)
      change_status(resource_id, "out_of_service", Public::ResourceTakenOutOfService)
    end

    def remove_resource(resource_id:)
      change_status(resource_id, "removed", Public::ResourceRemoved)
    end

    private

    def add_resource(resource_type:, name:, zone: nil, capacity: nil)
      resource_id = SecureRandom.uuid_v7
      transaction do
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
      transaction do
        resource = ReadModels::Resource.find(resource_id)
        resource.update!(status: status)
        publish(event_class.new(data: { resource_id: resource_id, resource_type: resource.resource_type }), resource_id)
      end
    end

    def hours(opens_at_hour, closes_at_hour)
      opens, closes = Integer(opens_at_hour), Integer(closes_at_hour)
      raise ArgumentError, "availability hours must be within 0-24 and open before close" unless (0...closes).cover?(opens) && closes <= 24

      [opens, closes]
    end

    def transaction(&) = ActiveRecord::Base.transaction(&)

    def publish(event, resource_id) = Rails.configuration.event_store.publish(event, stream_name: stream(resource_id))

    def stream(resource_id) = "Inventory::Resource$#{resource_id}"
  end
end
