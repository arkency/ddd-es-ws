# frozen_string_literal: true

module Invoicing
  # Public entry point: one line per vertical slice. The ACLs translate every upstream into
  # Invoicing's own words before calling here.
  module Commands
    extend self

    def register_billing_terms(...) = RegisterBillingTerms::Handler.new.call(RegisterBillingTerms::Command.new(...))
    def generate_invoice(...) = GenerateInvoice::Handler.new.call(GenerateInvoice::Command.new(...))
    def record_settlement(...) = RecordSettlement::Handler.new.call(RecordSettlement::Command.new(...))
  end
end
