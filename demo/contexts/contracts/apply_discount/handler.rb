# frozen_string_literal: true

module Contracts
  module ApplyDiscount
    class Handler
      def call(command)
        Internal::Repository.with_agreement(command.agreement_id) do |agreement|
          agreement.apply_discount(percent: command.percent)
        end
      end
    end
  end
end
