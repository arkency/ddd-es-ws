# frozen_string_literal: true

module Payments
  module GatewayConfirmed
    class Handler
      def call(command)
        Internal::Repository.with_payment(command.payment_id, &:receive)
      end
    end
  end
end
