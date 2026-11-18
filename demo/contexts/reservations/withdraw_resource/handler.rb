# frozen_string_literal: true

module Reservations
  module WithdrawResource
    class Handler
      def call(command)
        ReadModels::Catalog.withdraw(command.resource_id)
      end
    end
  end
end
