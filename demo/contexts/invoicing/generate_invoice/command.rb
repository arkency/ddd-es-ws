# frozen_string_literal: true

module Invoicing
  module GenerateInvoice
    # Idempotent per order: a redelivered event does not issue a second invoice.
    Command = Data.define(:order_ref, :contract_ref, :buyer_name, :description, :net_cents)
  end
end
