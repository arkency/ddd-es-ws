# frozen_string_literal: true

# Invoicing: issues and sends invoices, matches them with settlements.
# Context map: ACL downstream of Reservations, Payments and Contracts.
# Upstream of nobody, so it has no public events.
module Invoicing
  BillingTermsRegistered = Class.new(RubyEventStore::Event) # contract_ref, buyer_name, tax_id, payment_terms_days
  InvoiceGenerated = Class.new(RubyEventStore::Event)       # invoice_id, number, order_ref, buyer_name, net_cents
  InvoiceSent = Class.new(RubyEventStore::Event)            # invoice_id, recipient
  SettlementRecorded = Class.new(RubyEventStore::Event)     # order_ref, amount_cents
end
