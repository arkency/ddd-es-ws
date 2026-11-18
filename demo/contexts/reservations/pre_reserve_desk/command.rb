# frozen_string_literal: true

module Reservations
  module PreReserveDesk
    # Desk pre-reservation -> offer presented for the whole opening hours of that day.
    # The offer takes a temporary hold; payment turns it into a full hold (see Settle).
    Command = Data.define(:client, :resource_id, :date) do
      def initialize(client:, resource_id:, date:) = super(client: client, resource_id: resource_id, date: Date.iso8601(date.to_s))
    end
  end
end
