# frozen_string_literal: true

module Invoicing
  module RegisterBillingTerms
    Command = Data.define(:contract_ref, :buyer_name, :tax_id, :payment_terms_days)
  end
end
