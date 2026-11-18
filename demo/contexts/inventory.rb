# frozen_string_literal: true

# Inventory: which resources physically exist (desks and conference rooms).
# Context map: OHS/PL upstream of Pricing (Conformist), Reservations (ACL) and Availability (ACL).
#
# The published language is deliberately generic: a resource with a UUIDv7, a resource_type and
# the attributes that type has. Private events may still speak the UI's language (photos).
module Inventory
  PhotoAdded = Class.new(RubyEventStore::Event) # resource_id, url
end
