# frozen_string_literal: true

module Negotiations
  module ReadModels
    # `terms` is Contracts' terms hash, stored exactly as Contracts published it.
    class Negotiation < ActiveRecord::Base
      self.table_name = "negotiations_negotiations"
      self.primary_key = "agreement_id"
    end

    class Projection
      def call(event)
        data = event.data
        negotiation = Negotiation.find_or_initialize_by(agreement_id: data[:agreement_id])
        negotiation.history = Array(negotiation.history) + [event.event_type.demodulize.titleize]
        negotiation.terms = data[:terms] if data.key?(:terms)

        case event
        when NegotiationOpened then negotiation.status = "open"
        when PriceChangeProposed, AvailabilityHoursChangeProposed
          negotiation.open_proposal = data.except(:agreement_id).merge(kind: event.is_a?(PriceChangeProposed) ? "price" : "hours")
        when PriceChangeRejected, AvailabilityHoursChangeRejected, PriceChangeAccepted, AvailabilityHoursChangeAccepted
          negotiation.open_proposal = nil
        when NegotiationsConcluded then negotiation.status = "concluded"
        when NegotiationsProcessAbandoned then negotiation.status = "abandoned: #{data[:reason]}"
        end
        negotiation.save!
      end
    end
  end
end
