# frozen_string_literal: true

module Pricing
  # Public events: Pricing's Open Host Service / Published Language.
  # Deliberately generic: one event for every priced resource.
  #   resource_id   - the id of the thing being priced
  #   resource_type - "desk" | "conference_room"
  #   price_cents   - the amount
  #   price_unit    - "day" | "hour"
  module Public
    PricingAssigned = Class.new(RubyEventStore::Event)
  end
end
