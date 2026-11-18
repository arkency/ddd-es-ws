# frozen_string_literal: true

module Contracts
  module RequestQuote
    class Handler
      def call(command)
        agreement_id = SecureRandom.uuid
        Internal::Repository.with_agreement(agreement_id) do |agreement|
          agreement.request_quote(
            client_name: command.client_name, company: command.company, tax_id: command.tax_id,
            room_id: command.room_id, date: command.date,
            from_hour: command.from_hour, to_hour: command.to_hour,
          )
        end
        agreement_id
      end
    end
  end
end
