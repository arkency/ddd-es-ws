# frozen_string_literal: true

module Contracts
  module ChangeHours
    Command = Data.define(:agreement_id, :from_hour, :to_hour) do
      def initialize(agreement_id:, from_hour:, to_hour:)
        super(agreement_id: agreement_id, from_hour: Integer(from_hour), to_hour: Integer(to_hour))
      end
    end
  end
end
