# frozen_string_literal: true

module Negotiations
  module ProposeHoursChange
    Command = Data.define(:agreement_id, :from_hour, :to_hour, :proposed_by) do
      def initialize(agreement_id:, from_hour:, to_hour:, proposed_by:)
        super(
          agreement_id: agreement_id, from_hour: Integer(from_hour),
          to_hour: Integer(to_hour), proposed_by: proposed_by,
        )
      end
    end
  end
end
