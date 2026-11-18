# frozen_string_literal: true

module Negotiations
  module Abandon
    class Handler
      def call(command)
        client_name = ReadModels::Negotiation.find(command.agreement_id).terms.fetch("client_name")
        Internal::Repository.with_negotiation(command.agreement_id) do |negotiation|
          negotiation.abandon(reason: command.reason, client_name: client_name)
        end
      end
    end
  end
end
