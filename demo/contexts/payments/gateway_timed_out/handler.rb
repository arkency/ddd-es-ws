# frozen_string_literal: true

module Payments
  module GatewayTimedOut
    class Handler
      def call(command)
        Internal::Repository.with_payment(command.payment_id, &:time_out)
      end
    end
  end
end
