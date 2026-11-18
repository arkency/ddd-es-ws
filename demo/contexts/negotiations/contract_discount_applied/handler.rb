# frozen_string_literal: true

module Negotiations
  module ContractDiscountApplied
    class Handler
      def call(command)
        Internal::Repository.with_negotiation(command.terms[:agreement_id]) do |negotiation|
          negotiation.contract_discount_applied(terms: command.terms)
        end
      end
    end
  end
end
