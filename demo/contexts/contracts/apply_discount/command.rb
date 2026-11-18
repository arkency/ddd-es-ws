# frozen_string_literal: true

module Contracts
  module ApplyDiscount
    Command = Data.define(:agreement_id, :percent) do
      def initialize(agreement_id:, percent:) = super(agreement_id: agreement_id, percent: Integer(percent))
    end
  end
end
