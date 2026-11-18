# frozen_string_literal: true

module Inventory
  module AddConferenceRoom
    class Handler
      def call(command)
        Internal::Resources.add(
          resource_type: ReadModels::Resource::CONFERENCE_ROOM, name: command.name, capacity: command.capacity,
        )
      end
    end
  end
end
