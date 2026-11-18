# frozen_string_literal: true

module Negotiations
  module ProposePriceChange
    class Handler
      def call(command)
        Internal::Repository.with_negotiation(command.agreement_id) do |negotiation|
          negotiation.propose_price_change(price_cents: command.price_cents, proposed_by: command.proposed_by)
        end
      end
    end
  end
end
