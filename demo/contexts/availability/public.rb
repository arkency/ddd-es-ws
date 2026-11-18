# frozen_string_literal: true

module Availability
  # Public API of Availability: a capability with no process of its own. On the context map
  # this is an Open Host Service exposed as a synchronous in-process facade (we are a monolith);
  # there are no public events.
  #
  # Only Reservations (the process on top of it) calls this. The UI never calls Availability directly;
  # opening hours arrive from Inventory's events (Integrations::InventoryAcl).
  # Callers get an immediate, consistent answer; in exchange they are coupled in time:
  # if Availability is broken, the caller's command fails too.
  module Public
    Period = Data.define(:resource_id, :date, :from_hour, :to_hour)
    NotAvailable = Class.new(StandardError)

    extend self

    # Whole opening hours of a resource on a date, or nil when hours were never defined.
    def opening_hours(resource_id:, date:)
      hours = Internal::OpeningHours.find_by(resource_id: resource_id)
      hours && Period.new(resource_id: resource_id, date: date, from_hour: hours.opens_at_hour, to_hour: hours.closes_at_hour)
    end

    # Self-service hold: inside opening hours only. Raises NotAvailable.
    def temporarily_block(period, reference:) = Internal::Resources.temporarily_block(period, reference: reference)

    # Full hold: paid or agreed. Converts a temporary hold of the same reference. Raises NotAvailable.
    def block(period, reference:) = Internal::Resources.block(period, reference: reference)

    def unblock(resource_id:, reference:) = Internal::Resources.unblock(resource_id: resource_id, reference: reference)

    def cancel_temporary_block(resource_id:, reference:)
      Internal::Resources.cancel_temporary_block(resource_id: resource_id, reference: reference)
    end
  end
end
