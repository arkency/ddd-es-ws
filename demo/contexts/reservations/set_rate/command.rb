# frozen_string_literal: true

module Reservations
  module SetRate
    Command = Data.define(:resource_id, :resource_type, :rate_cents, :rate_unit)
  end
end
