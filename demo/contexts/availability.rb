# frozen_string_literal: true

# Availability: held slots of every bookable resource, and the opening hours Inventory gives it.
# Context map:
#   ACL downstream of Inventory (opening hours arrive as Inventory's events)  -- async events
#   OHS (no PL) upstream of Reservations (Conformist), via the sync facade Availability::Public
#
# Event-sourced per resource: Availability::Internal::Resource, stream "Availability::Resource$<id>".
# The events below are private: they are never published to other contexts.
module Availability
  OpeningHoursRecorded = Class.new(RubyEventStore::Event)        # resource_id, opens_at_hour, closes_at_hour
  OpeningHoursForgotten = Class.new(RubyEventStore::Event)       # resource_id
  SlotTemporarilyBlocked = Class.new(RubyEventStore::Event)      # resource_id, reference, date, from_hour, to_hour
  SlotBlocked = Class.new(RubyEventStore::Event)                 # resource_id, reference, date, from_hour, to_hour
  SlotUnblocked = Class.new(RubyEventStore::Event)               # resource_id, reference
  SlotTemporaryBlockCancelled = Class.new(RubyEventStore::Event) # resource_id, reference

  def self.subscribe_internal(event_store)
    event_store.subscribe(ReadModels::Projection.new, to: [OpeningHoursRecorded, OpeningHoursForgotten])
  end
end
