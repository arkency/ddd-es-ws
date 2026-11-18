# frozen_string_literal: true

module Contracts
  module ReadModels
    class Agreement < ActiveRecord::Base
      self.table_name = "contracts_agreements"
    end

    class Projection
      def call(event)
        data = event.data
        agreement = Agreement.find_or_initialize_by(id: data[:agreement_id])
        case event
        when QuoteRequested then agreement.update!(terms(data).merge(status: "requested"))
        when DraftAgreementCreated then agreement.update!(terms(data).merge(status: "draft"))
        when Public::DraftAgreementSent then agreement.update!(status: "sent")
        when Public::AgreementTermsChanged, Public::DiscountApplied then agreement.update!(terms(data))
        when AgreementGenerated then agreement.update!(status: "generated", document_id: data[:document_id])
        when Public::AgreementSigned then agreement.update!(status: "signed")
        end
      end

      private

      def terms(data) = data.except(:agreement_id, :changed)
    end
  end
end
