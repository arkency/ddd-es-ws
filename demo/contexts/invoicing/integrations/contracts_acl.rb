# frozen_string_literal: true

module Invoicing
  module Integrations
    # ANTI-CORRUPTION LAYER over Contracts.
    # From a signed agreement we keep only billing terms: who is the buyer (the company,
    # not the person who signed), their tax id, and payment terms. Everything else is ignored.
    class ContractsAcl < IntegrationJob
      PAYMENT_TERMS_FOR_COMPANIES = 14

      def call(event)
        data = event.data
        Commands.register_billing_terms(
          contract_ref: data[:agreement_id],
          buyer_name: data[:company],
          tax_id: data[:tax_id],
          payment_terms_days: PAYMENT_TERMS_FOR_COMPANIES,
        )
      end
    end
  end
end
