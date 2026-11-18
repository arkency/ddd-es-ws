# frozen_string_literal: true

# Negotiations: the back-and-forth on price and hours between client and manager.
# Context map: Conformist downstream of Contracts. Upstream of nobody, so it has no public events.
module Negotiations
  NegotiationOpened = Class.new(RubyEventStore::Event)               # agreement_id, terms (Contracts' terms, verbatim)
  PriceChangeProposed = Class.new(RubyEventStore::Event)             # agreement_id, proposed_by, price_cents
  AvailabilityHoursChangeProposed = Class.new(RubyEventStore::Event) # agreement_id, proposed_by, from_hour, to_hour
  PriceChangeRejected = Class.new(RubyEventStore::Event)             # agreement_id
  AvailabilityHoursChangeRejected = Class.new(RubyEventStore::Event) # agreement_id
  PriceChangeAccepted = Class.new(RubyEventStore::Event)             # agreement_id, terms
  AvailabilityHoursChangeAccepted = Class.new(RubyEventStore::Event) # agreement_id, terms
  TermsChanged = Class.new(RubyEventStore::Event)                    # agreement_id, terms (changed in Contracts w/o proposal)
  DiscountApplied = Class.new(RubyEventStore::Event)                 # agreement_id, terms
  NegotiationsConcluded = Class.new(RubyEventStore::Event)           # agreement_id, terms
  NegotiationsProcessAbandoned = Class.new(RubyEventStore::Event)    # agreement_id, reason
  ClientLost = Class.new(RubyEventStore::Event)                      # agreement_id, client_name

  def self.subscribe_internal(event_store)
    event_store.subscribe(
      ReadModels::Projection.new,
      to: [
        NegotiationOpened, PriceChangeProposed, AvailabilityHoursChangeProposed,
        PriceChangeRejected, AvailabilityHoursChangeRejected, PriceChangeAccepted, AvailabilityHoursChangeAccepted,
        TermsChanged, DiscountApplied, NegotiationsConcluded, NegotiationsProcessAbandoned, ClientLost,
      ],
    )
  end
end
