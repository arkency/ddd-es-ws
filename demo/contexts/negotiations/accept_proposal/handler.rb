# frozen_string_literal: true

module Negotiations
  module AcceptProposal
    class Handler
      NothingToAccept = Class.new(StandardError)

      def call(command)
        proposal = ReadModels::Negotiation.find(command.agreement_id).open_proposal
        raise NothingToAccept, "nothing proposed for #{command.agreement_id}" unless proposal

        case proposal.fetch("kind")
        when "price"
          Contracts::Commands.change_price(
            agreement_id: command.agreement_id, price_cents: proposal.fetch("price_cents"),
          )
        when "hours"
          Contracts::Commands.change_hours(
            agreement_id: command.agreement_id,
            from_hour: proposal.fetch("from_hour"), to_hour: proposal.fetch("to_hour"),
          )
        end
      end
    end
  end
end
