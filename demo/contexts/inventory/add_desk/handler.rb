# frozen_string_literal: true

module Inventory
  module AddDesk
    class Handler
      def call(command)
        Internal::Resources.add(resource_type: ReadModels::Resource::DESK, name: command.name, zone: command.zone)
      end
    end
  end
end
