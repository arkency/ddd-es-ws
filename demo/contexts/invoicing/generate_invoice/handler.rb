# frozen_string_literal: true

module Invoicing
  module GenerateInvoice
    class Handler
      def call(command)
        return if ReadModels::Invoice.exists?(order_ref: command.order_ref)

        # Async: billing terms from Contracts may not have arrived yet. Then we bill the client
        # directly with immediate payment terms -- a business decision, made visible here.
        terms = command.contract_ref && ReadModels::BillingTerms.find_by(contract_ref: command.contract_ref)
        ActiveRecord::Base.transaction do
          invoice = ReadModels::Invoice.create!(
            id: SecureRandom.uuid,
            order_ref: command.order_ref,
            number: "INV/#{Date.current.year}/#{ReadModels::Invoice.count + 1}",
            buyer_name: terms&.buyer_name || command.buyer_name,
            tax_id: terms&.tax_id,
            description: command.description,
            net_cents: command.net_cents,
            payment_terms_days: terms&.payment_terms_days || 0,
            status: "generated",
          )
          Internal::Publication.publish(
            InvoiceGenerated.new(
              data: { invoice_id: invoice.id, number: invoice.number, order_ref: command.order_ref,
                      buyer_name: invoice.buyer_name, net_cents: command.net_cents },
            ),
          )

          External::MailingSystem.deliver(
            sender: "Invoicing", recipient: invoice.buyer_name, subject: "Invoice #{invoice.number}",
          )
          invoice.update!(status: "sent")
          Internal::Publication.publish(InvoiceSent.new(data: { invoice_id: invoice.id, recipient: invoice.buyer_name }))
        end
      end
    end
  end
end
