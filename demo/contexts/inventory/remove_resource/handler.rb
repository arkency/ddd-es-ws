# frozen_string_literal: true

module Inventory
  module RemoveResource
    class Handler
      def call(command)
        Internal::Resources.change_status(command.resource_id, "removed", Public::ResourceRemoved)
      end
    end
  end
end
