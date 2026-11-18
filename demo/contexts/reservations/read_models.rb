# frozen_string_literal: true

module Reservations
  module ReadModels
    # What Reservations knows about Inventory, split by resource type.
    # Each table is projected from Inventory's generic ResourceAdded event (and its updates);
    # the type-specific columns stay type-specific. The ACL routes on resource_type.
    class Desk < ActiveRecord::Base
      self.table_name = "reservations_desks"
      self.primary_key = "resource_id"

      def resource_type = "desk"
      def label = name ? "Desk #{name} (#{zone})" : resource_id
    end

    class ConferenceRoom < ActiveRecord::Base
      self.table_name = "reservations_conference_rooms"
      self.primary_key = "resource_id"

      def resource_type = "conference_room"
      def label = name ? "#{name} (#{capacity} seats)" : resource_id
    end

    # A reservation is process state, not an aggregate: one row per reservation, moved through
    # awaiting_payment -> reserved | expired, or rejected when Availability says no.
    class Reservation < ActiveRecord::Base
      self.table_name = "reservations_reservations"
    end

    # The two inventory tables, addressed generically by resource id / type.
    module Catalog
      extend self

      MODELS = { "desk" => Desk, "conference_room" => ConferenceRoom }.freeze

      def model_for(resource_type) = MODELS[resource_type]

      def withdraw(resource_id)
        MODELS.each_value { |model| model.where(resource_id: resource_id).update_all(withdrawn: true) }
      end
    end
  end
end
