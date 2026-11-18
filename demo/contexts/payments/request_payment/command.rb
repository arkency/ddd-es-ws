# frozen_string_literal: true

module Payments
  module RequestPayment
    # Checkout: someone (here: the UI) asks to collect an amount for an opaque reference.
    Command = Data.define(:reference, :payer, :amount_cents) do
      def initialize(reference:, payer:, amount_cents:) = super(reference: reference, payer: payer, amount_cents: Integer(amount_cents))
    end
  end
end
