# frozen_string_literal: true

module Availability
  module Internal
    # Loads a Resource, runs one behaviour on it, and stores the events it emitted.
    # The store checks the stream version, so two bookings racing for the same resource cannot both succeed.
    module Resources
      extend self

      def record_opening_hours(resource_id:, opens_at_hour:, closes_at_hour:)
        with_resource(resource_id) do |resource|
          resource.record_opening_hours(opens_at_hour: opens_at_hour, closes_at_hour: closes_at_hour)
        end
      end

      def forget_opening_hours(resource_id:) = with_resource(resource_id, &:forget_opening_hours)

      def temporarily_block(period, reference:)
        with_resource(period.resource_id) do |resource|
          resource.temporarily_block(date: period.date, from_hour: period.from_hour, to_hour: period.to_hour, reference: reference)
        end
      end

      def block(period, reference:)
        with_resource(period.resource_id) do |resource|
          resource.block(date: period.date, from_hour: period.from_hour, to_hour: period.to_hour, reference: reference)
        end
      end

      def unblock(resource_id:, reference:) = with_resource(resource_id) { |resource| resource.unblock(reference: reference) }

      def cancel_temporary_block(resource_id:, reference:)
        with_resource(resource_id) { |resource| resource.cancel_temporary_block(reference: reference) }
      end

      private

      def with_resource(id, &)
        AggregateRoot::Repository.new(Rails.configuration.event_store)
                                 .with_aggregate(Resource.new(id), "Availability::Resource$#{id}", &)
      end
    end
  end
end
