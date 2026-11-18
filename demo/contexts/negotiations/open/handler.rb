# frozen_string_literal: true

module Negotiations
  module Open
    class Handler
      def call(command)
        return if ReadModels::Negotiation.exists?(command.terms[:agreement_id]) # redelivered event

        Internal::Repository.with_negotiation(command.terms[:agreement_id]) do |negotiation|
          negotiation.open(terms: command.terms)
        end
      end
    end
  end
end
