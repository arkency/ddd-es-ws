# frozen_string_literal: true

module Reservations
  module SetRate
    class Handler
      def call(command)
        model = ReadModels::Catalog.model_for(command.resource_type)
        return unless model

        model.find_or_initialize_by(resource_id: command.resource_id)
             .update!(rate_cents: command.rate_cents, rate_unit: command.rate_unit)
      end
    end
  end
end
