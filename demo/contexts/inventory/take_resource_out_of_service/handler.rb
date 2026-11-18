# frozen_string_literal: true

module Inventory
  module TakeResourceOutOfService
    class Handler
      def call(command)
        Internal::Resources.change_status(command.resource_id, "out_of_service", Public::ResourceTakenOutOfService)
      end
    end
  end
end
