# frozen_string_literal: true

module Invoicing
  module RecordSettlement
    Command = Data.define(:order_ref, :amount_cents)
  end
end
