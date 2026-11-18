# frozen_string_literal: true

module Reservations
  module Integrations
    # CONFORMIST over a synchronous Open Host Service.
    #
    # No translation: Reservations passes and receives Availability's own types
    # (Availability::Public::Period) and lets its NotAvailable error propagate.
    # This module exists only to make the edge visible (and logged); it adds no model of its own.
    #
    # Sync means: the answer is consistent right now, but if Availability fails,
    # pre-reserving a desk fails too.
    module AvailabilityConformist
      extend self

      def opening_hours(resource_id:, date:)
        sync("opening_hours") { Availability::Public.opening_hours(resource_id: resource_id, date: date) }
      end

      def temporarily_block(period, reference:)
        sync("temporarily_block") { Availability::Public.temporarily_block(period, reference: reference) }
      end

      def block(period, reference:) = sync("block") { Availability::Public.block(period, reference: reference) }

      # Drops whatever this reference holds on the resource: a temporary hold, or a full one.
      def release(resource_id:, reference:)
        sync("release") do
          Availability::Public.cancel_temporary_block(resource_id: resource_id, reference: reference)
          Availability::Public.unblock(resource_id: resource_id, reference: reference)
        end
      end

      private

      # A sync call leaves no event, so it is logged directly, with the read-model tables it wrote.
      def sync(call)
        result, tables = ReadModelTracker.track { yield }
        IntegrationLog.record(integration: name, message: "#{call} (sync call)", tables: tables)
        result
      end
    end
  end
end
