# frozen_string_literal: true

module Invoicing
  # Invoicing's own language: orders, buyers, billing terms, settlements.
  # The ACLs translate every upstream into these calls.
  module Commands
    extend self

    def register_billing_terms(contract_ref:, buyer_name:, tax_id:, payment_terms_days:)
      ActiveRecord::Base.transaction do
        ReadModels::BillingTerms.find_or_initialize_by(contract_ref: contract_ref)
                                .update!(buyer_name: buyer_name, tax_id: tax_id, payment_terms_days: payment_terms_days)
        publish(BillingTermsRegistered.new(data: { contract_ref: contract_ref, buyer_name: buyer_name, tax_id: tax_id,
                                                   payment_terms_days: payment_terms_days }))
      end
    end

    # Idempotent per order: a redelivered event does not issue a second invoice.
    def generate_invoice(order_ref:, contract_ref:, buyer_name:, description:, net_cents:)
      return if ReadModels::Invoice.exists?(order_ref: order_ref)

      # Async: billing terms from Contracts may not have arrived yet. Then we bill the client
      # directly with immediate payment terms -- a business decision, made visible here.
      terms = contract_ref && ReadModels::BillingTerms.find_by(contract_ref: contract_ref)
      ActiveRecord::Base.transaction do
        invoice = ReadModels::Invoice.create!(
          id: SecureRandom.uuid,
          order_ref: order_ref,
          number: "INV/#{Date.current.year}/#{ReadModels::Invoice.count + 1}",
          buyer_name: terms&.buyer_name || buyer_name,
          tax_id: terms&.tax_id,
          description: description,
          net_cents: net_cents,
          payment_terms_days: terms&.payment_terms_days || 0,
          status: "generated",
        )
        publish(InvoiceGenerated.new(data: { invoice_id: invoice.id, number: invoice.number, order_ref: order_ref,
                                             buyer_name: invoice.buyer_name, net_cents: net_cents }))

        External::MailingSystem.deliver(sender: "Invoicing", recipient: invoice.buyer_name, subject: "Invoice #{invoice.number}")
        invoice.update!(status: "sent")
        publish(InvoiceSent.new(data: { invoice_id: invoice.id, recipient: invoice.buyer_name }))
      end
    end

    def record_settlement(order_ref:, amount_cents:)
      ActiveRecord::Base.transaction do
        ReadModels::Settlement.find_or_initialize_by(order_ref: order_ref).update!(amount_cents: amount_cents)
        publish(SettlementRecorded.new(data: { order_ref: order_ref, amount_cents: amount_cents }))
      end
    end

    private

    def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "Invoicing")
  end
end
