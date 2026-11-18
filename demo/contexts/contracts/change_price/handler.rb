# frozen_string_literal: true

module Contracts
  module ChangePrice
    class Handler
      def call(command)
        Internal::Repository.with_agreement(command.agreement_id) do |agreement|
          agreement.change_price(price_cents: command.price_cents)
        end
      end
    end
  end
end
