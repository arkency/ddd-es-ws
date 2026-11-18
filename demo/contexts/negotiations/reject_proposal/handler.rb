# frozen_string_literal: true

module Negotiations
  module RejectProposal
    class Handler
      def call(command)
        Internal::Repository.with_negotiation(command.agreement_id, &:reject_proposal)
      end
    end
  end
end
