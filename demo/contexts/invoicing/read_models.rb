# frozen_string_literal: true

module Invoicing
  module ReadModels
    class BillingTerms < ActiveRecord::Base
      self.table_name = "invoicing_billing_terms"
      self.primary_key = "contract_ref"
    end

    class Invoice < ActiveRecord::Base
      self.table_name = "invoicing_invoices"

      def settled? = Settlement.exists?(order_ref)
    end

    class Settlement < ActiveRecord::Base
      self.table_name = "invoicing_settlements"
      self.primary_key = "order_ref"
    end
  end
end
