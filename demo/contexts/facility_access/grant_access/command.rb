# frozen_string_literal: true

module FacilityAccess
  module GrantAccess
    # Idempotent per booking.
    Command = Data.define(:booking_ref, :holder, :zone, :valid_on, :from_hour, :to_hour)
  end
end
