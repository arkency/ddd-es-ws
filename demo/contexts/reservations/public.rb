# frozen_string_literal: true

module Reservations
  # Published Language. One event for both resource types: the downstream ACL translates
  # resource_type into its own words (Facility Access: a desk is on the co-work floor).
  #
  # Data: reservation_id, resource_id, resource_type, client, label, date,
  #       from_hour, to_hour, amount_cents (+ agreement_ref for conference rooms).
  module Public
    ReservationConfirmed = Class.new(RubyEventStore::Event)
  end
end
