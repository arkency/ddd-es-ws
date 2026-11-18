# frozen_string_literal: true

module Negotiations
  module ProposeHoursChange
    class Handler
      def call(command)
        Internal::Repository.with_negotiation(command.agreement_id) do |negotiation|
          negotiation.propose_hours_change(
            from_hour: command.from_hour, to_hour: command.to_hour, proposed_by: command.proposed_by,
          )
        end
      end
    end
  end
end
