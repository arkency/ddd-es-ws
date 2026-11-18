# frozen_string_literal: true

module Negotiations
  module Internal
    # Loads one negotiation aggregate, runs one behaviour, and stores the events it emitted.
    module Repository
      extend self

      def with_negotiation(agreement_id, &)
        ActiveRecord::Base.transaction do
          AggregateRoot::Repository.new(Rails.configuration.event_store)
                                   .with_aggregate(Negotiation.new(agreement_id), "Negotiations::Negotiation$#{agreement_id}", &)
        end
      end
    end
  end
end
