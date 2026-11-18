# frozen_string_literal: true

# Reservations: the process. Turns "a client wants this resource at that time" into a paid
# reservation, by asking Availability to hold the slot and publishing the facts downstream.
#
# There is no Reservation aggregate. A reservation has no invariant of its own: the only
# decision that must be serialized -- "is this slot free?" -- lives in Availability's aggregate.
# Everything else (which resource, which type, what price, whether it is withdrawn) is data
# Reservations already projects from Inventory and Pricing. So the reservation is a read model
# the commands move through its states, not an event-sourced aggregate.
#
# Context map:
#   downstream (ACL)        of Inventory, Pricing, Payments, Contracts   -- async events
#   downstream (Conformist) of Availability                              -- sync facade
#   upstream (OHS/PL)       of Invoicing and Facility Access              -- async events
#
# Events defined here are private facts of the process; only Public::ReservationConfirmed is
# part of Reservations' published language.
module Reservations
  ReservationRequested = Class.new(RubyEventStore::Event)
  ReservationRejected = Class.new(RubyEventStore::Event)
  ReservationExpired = Class.new(RubyEventStore::Event)
end
