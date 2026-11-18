# frozen_string_literal: true

module Inventory
  # Public events: the only Inventory classes other contexts may reference. On the context map
  # this is Inventory's Open Host Service / Published Language.
  # Changing a payload here is a breaking change for every downstream context.
  #
  # Inventory publishes *resources*, not UI features. A desk and a conference room are the same
  # kind of thing to the rest of the system: a resource with an id, a type and the attributes
  # that type happens to have (zone for a desk, capacity for a room). Reservations and Pricing
  # route on resource_type; they never need a DeskAdded/ConferenceRoomAdded pair.
  module Public
    ResourceAdded = Class.new(RubyEventStore::Event)             # resource_id, resource_type, name, zone/capacity
    ResourceHoursAdded = Class.new(RubyEventStore::Event)        # resource_id, resource_type, opens_at_hour, closes_at_hour
    ResourceTakenOutOfService = Class.new(RubyEventStore::Event) # resource_id, resource_type
    ResourceRemoved = Class.new(RubyEventStore::Event)           # resource_id, resource_type
  end
end
