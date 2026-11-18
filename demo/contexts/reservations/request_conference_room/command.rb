# frozen_string_literal: true

module Reservations
  module RequestConferenceRoom
    # A signed agreement reserves the room for the agreed hours. The agreement is the decision,
    # so a room that is free is booked even outside its opening hours; only a clash rejects it.
    Command = Data.define(:agreement_ref, :client, :resource_id, :date, :from_hour, :to_hour, :amount_cents)
  end
end
