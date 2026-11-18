# frozen_string_literal: true

module Inventory
  module ReadModels
    # One table for every resource. resource_type says what it is; the attributes the type
    # needs (zone, capacity) are just columns here. This is what "resource" means in the
    # published language: the UI may still show two tables, the model does not.
    class Resource < ActiveRecord::Base
      self.table_name = "inventory_resources"

      DESK = "desk"
      CONFERENCE_ROOM = "conference_room"

      def desk? = resource_type == DESK
    end
  end
end
