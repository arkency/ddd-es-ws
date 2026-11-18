# frozen_string_literal: true

module Contracts
  module Generate
    class Handler
      def call(command)
        document_id = External::DocuWare.generate(agreement_id: command.agreement_id)
        Internal::Repository.with_agreement(command.agreement_id) do |agreement|
          agreement.generate(document_id: document_id)
        end
      end
    end
  end
end
