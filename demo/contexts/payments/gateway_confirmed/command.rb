# frozen_string_literal: true

module Payments
  module GatewayConfirmed
    # Payment gateway callback (simulated by a button in the UI).
    Command = Data.define(:payment_id)
  end
end
