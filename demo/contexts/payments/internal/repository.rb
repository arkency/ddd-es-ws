# frozen_string_literal: true

module Payments
  module Internal
    # Loads one payment aggregate, runs one behaviour, and stores the events it emitted.
    module Repository
      extend self

      def with_payment(id, &)
        ActiveRecord::Base.transaction do
          AggregateRoot::Repository.new(Rails.configuration.event_store)
                                   .with_aggregate(Payment.new(id), "Payments::Payment$#{id}", &)
        end
      end
    end
  end
end
