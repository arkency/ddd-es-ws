# frozen_string_literal: true

module Contracts
  module RequestQuote
    # The client asks for a room. No price yet: the manager prices the quote.
    Command = Data.define(:client_name, :company, :tax_id, :room_id, :date, :from_hour, :to_hour) do
      def initialize(client_name:, company:, tax_id:, room_id:, date:, from_hour:, to_hour:)
        super(
          client_name: client_name, company: company, tax_id: tax_id, room_id: room_id,
          date: Date.iso8601(date.to_s), from_hour: Integer(from_hour), to_hour: Integer(to_hour),
        )
      end
    end
  end
end
