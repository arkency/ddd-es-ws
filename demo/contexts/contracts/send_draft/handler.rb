# frozen_string_literal: true

module Contracts
  module SendDraft
    class Handler
      def call(command)
        Internal::Repository.with_agreement(command.agreement_id, &:send_to_client)
      end
    end
  end
end
