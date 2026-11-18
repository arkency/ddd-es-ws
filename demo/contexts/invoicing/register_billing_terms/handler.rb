# frozen_string_literal: true

module Invoicing
  module RegisterBillingTerms
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          ReadModels::BillingTerms.find_or_initialize_by(contract_ref: command.contract_ref).update!(
            buyer_name: command.buyer_name, tax_id: command.tax_id,
            payment_terms_days: command.payment_terms_days,
          )
          Internal::Publication.publish(
            BillingTermsRegistered.new(
              data: { contract_ref: command.contract_ref, buyer_name: command.buyer_name,
                      tax_id: command.tax_id, payment_terms_days: command.payment_terms_days },
            ),
          )
        end
      end
    end
  end
end
