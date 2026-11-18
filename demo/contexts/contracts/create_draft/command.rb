# frozen_string_literal: true

module Contracts
  module CreateDraft
    Command = Data.define(:agreement_id, :price_cents) do
      def initialize(agreement_id:, price_cents:) = super(agreement_id: agreement_id, price_cents: Integer(price_cents))
    end
  end
end
