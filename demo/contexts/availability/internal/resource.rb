# frozen_string_literal: true

module Availability
  module Internal
    # A bookable resource and the slots held on it. Event-sourced, one stream per resource.
    #
    # Opening hours are owned by Inventory. Availability's ACL (Integrations::InventoryAcl) records
    # the hours Inventory publishes here, and forgets them when Inventory removes the resource or
    # takes it out of service. The aggregate trusts those values; Inventory already validated them.
    #
    # Holds are keyed by reference (the reservation id):
    #   temporary -- taken when an offer is presented; the client has not paid yet
    #   full      -- taken when the payment is received, or when an agreement is signed
    #
    # Self-service holds (temporarily_block) must fall inside the recorded hours. Full holds only
    # need the slot to be free: a signed agreement is the decision, even outside opening hours.
    class Resource
      include AggregateRoot

      def initialize(id)
        @id = id
        @hours = nil
        @holds = {}
      end

      def record_opening_hours(opens_at_hour:, closes_at_hour:)
        apply OpeningHoursRecorded.new(data: { resource_id: @id, opens_at_hour: opens_at_hour, closes_at_hour: closes_at_hour })
      end

      def forget_opening_hours
        apply OpeningHoursForgotten.new(data: { resource_id: @id })
      end

      def temporarily_block(date:, from_hour:, to_hour:, reference:)
        return if @holds.key?(reference)
        raise Public::NotAvailable, "no opening hours defined" unless @hours

        unless from_hour >= @hours[:opens_at_hour] && to_hour <= @hours[:closes_at_hour]
          raise Public::NotAvailable, "outside opening hours #{@hours[:opens_at_hour]}-#{@hours[:closes_at_hour]}"
        end
        raise Public::NotAvailable, "already taken" if clashes?(date: date, from_hour: from_hour, to_hour: to_hour, reference: reference)

        apply SlotTemporarilyBlocked.new(data: slot(date: date, from_hour: from_hour, to_hour: to_hour, reference: reference))
      end

      # Converts a temporary hold of the same reference into a full one.
      def block(date:, from_hour:, to_hour:, reference:)
        return if @holds.dig(reference, :kind) == :full
        raise Public::NotAvailable, "already taken" if clashes?(date: date, from_hour: from_hour, to_hour: to_hour, reference: reference)

        apply SlotBlocked.new(data: slot(date: date, from_hour: from_hour, to_hour: to_hour, reference: reference))
      end

      def unblock(reference:)
        return unless @holds.dig(reference, :kind) == :full

        apply SlotUnblocked.new(data: { resource_id: @id, reference: reference })
      end

      def cancel_temporary_block(reference:)
        return unless @holds.dig(reference, :kind) == :temporary

        apply SlotTemporaryBlockCancelled.new(data: { resource_id: @id, reference: reference })
      end

      private

      def slot(date:, from_hour:, to_hour:, reference:)
        { resource_id: @id, reference: reference, date: date, from_hour: from_hour, to_hour: to_hour }
      end

      def clashes?(date:, from_hour:, to_hour:, reference:)
        @holds.any? do |other_reference, hold|
          other_reference != reference && hold[:date] == date && from_hour < hold[:to_hour] && hold[:from_hour] < to_hour
        end
      end

      on OpeningHoursRecorded do |event|
        @hours = event.data.slice(:opens_at_hour, :closes_at_hour)
      end

      on OpeningHoursForgotten do |_event|
        @hours = nil
      end

      on SlotTemporarilyBlocked do |event|
        @holds[event.data[:reference]] = event.data.slice(:date, :from_hour, :to_hour).merge(kind: :temporary)
      end

      on SlotBlocked do |event|
        @holds[event.data[:reference]] = event.data.slice(:date, :from_hour, :to_hour).merge(kind: :full)
      end

      on SlotUnblocked do |event|
        @holds.delete(event.data[:reference])
      end

      on SlotTemporaryBlockCancelled do |event|
        @holds.delete(event.data[:reference])
      end
    end
  end
end
