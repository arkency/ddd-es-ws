# frozen_string_literal: true

module Contracts
  module ChangeHours
    class Handler
      def call(command)
        Internal::Repository.with_agreement(command.agreement_id) do |agreement|
          agreement.change_hours(from_hour: command.from_hour, to_hour: command.to_hour)
        end
      end
    end
  end
end
