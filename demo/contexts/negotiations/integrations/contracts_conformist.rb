# frozen_string_literal: true

module Negotiations
  module Integrations
    # CONFORMIST: Negotiations adopts Contracts' model wholesale.
    #
    # - Our aggregate id is Contracts' agreement_id.
    # - We store Contracts' terms hash verbatim (client_name, price_cents, discount_percent, ...)
    #   and our UI reads those exact keys.
    # - We rely on Contracts' `changed` flag to decide which proposal got accepted.
    #
    # Rename a field in Contracts' Published Language and Negotiations breaks. We accept that
    # because Contracts is the source of truth for terms and we have no leverage to negotiate
    # a different model (that is what makes it Conformist rather than Customer/Supplier).
    class ContractsConformist < IntegrationJob
      def call(event)
        terms = event.data
        case event
        when Contracts::Public::DraftAgreementSent then Commands.open(terms: terms)
        when Contracts::Public::AgreementTermsChanged then Commands.contract_terms_changed(terms: terms)
        when Contracts::Public::DiscountApplied then Commands.contract_discount_applied(terms: terms)
        when Contracts::Public::AgreementSigned then Commands.conclude(terms: terms)
        end
      end
    end
  end
end
