# frozen_string_literal: true

module Negotiations
  module ProposePriceChange
    Command = Data.define(:agreement_id, :price_cents, :proposed_by) do
      def initialize(agreement_id:, price_cents:, proposed_by:)
        super(agreement_id: agreement_id, price_cents: Integer(price_cents), proposed_by: proposed_by)
      end
    end
  end
end
