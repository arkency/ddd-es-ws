# frozen_string_literal: true

module Payments
  # Public entry point: one line per vertical slice.
  module Commands
    extend self

    def request_payment(...) = RequestPayment::Handler.new.call(RequestPayment::Command.new(...))
    def gateway_confirmed(...) = GatewayConfirmed::Handler.new.call(GatewayConfirmed::Command.new(...))
    def gateway_timed_out(...) = GatewayTimedOut::Handler.new.call(GatewayTimedOut::Command.new(...))
  end
end
