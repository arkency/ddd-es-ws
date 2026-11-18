# frozen_string_literal: true

module Contracts
  module Sign
    class Handler
      def call(command)
        Internal::Repository.with_agreement(command.agreement_id, &:sign)
      end
    end
  end
end
