# frozen_string_literal: true

module Contracts
  module Internal
    # Loads one agreement aggregate, runs one behaviour, and stores the events it emitted.
    module Repository
      extend self

      def with_agreement(id, &)
        ActiveRecord::Base.transaction do
          AggregateRoot::Repository.new(Rails.configuration.event_store)
                                   .with_aggregate(Agreement.new(id), "Contracts::Agreement$#{id}", &)
        end
      end
    end
  end
end
