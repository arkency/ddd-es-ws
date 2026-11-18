# frozen_string_literal: true

module Negotiations
  module Commands
    extend self

    NothingToAccept = Class.new(StandardError)

    # --- UI ----------------------------------------------------------------------

    def propose_price_change(agreement_id:, price_cents:, proposed_by:)
      with_negotiation(agreement_id) { _1.propose_price_change(price_cents: Integer(price_cents), proposed_by: proposed_by) }
    end

    def propose_hours_change(agreement_id:, from_hour:, to_hour:, proposed_by:)
      with_negotiation(agreement_id) do
        _1.propose_hours_change(from_hour: Integer(from_hour), to_hour: Integer(to_hour), proposed_by: proposed_by)
      end
    end

    def reject_proposal(agreement_id:)
      with_negotiation(agreement_id, &:reject_proposal)
    end

    # Downstream calling upstream's command API is allowed: the dependency still points
    # Negotiations -> Contracts. But note the dance: we ask Contracts to change the terms,
    # then learn that *our own* proposal was accepted only when Contracts' event comes back
    # through ContractsConformist. That awkwardness is the hint that this relationship may
    # want to be flipped (Negotiations upstream, Contracts downstream).
    def accept_proposal(agreement_id:)
      proposal = ReadModels::Negotiation.find(agreement_id).open_proposal
      raise NothingToAccept, "nothing proposed for #{agreement_id}" unless proposal

      case proposal.fetch("kind")
      when "price"
        Contracts::Commands.change_price(agreement_id: agreement_id, price_cents: proposal.fetch("price_cents"))
      when "hours"
        Contracts::Commands.change_hours(agreement_id: agreement_id, from_hour: proposal.fetch("from_hour"), to_hour: proposal.fetch("to_hour"))
      end
    end

    def abandon(agreement_id:, reason:)
      client_name = ReadModels::Negotiation.find(agreement_id).terms.fetch("client_name")
      with_negotiation(agreement_id) { _1.abandon(reason: reason, client_name: client_name) }
    end

    # --- called by ContractsConformist, with Contracts' terms as-is --------------

    def open(terms:)
      return if ReadModels::Negotiation.exists?(terms[:agreement_id]) # redelivered event

      with_negotiation(terms[:agreement_id]) { _1.open(terms: terms) }
    end

    def contract_terms_changed(terms:)
      with_negotiation(terms[:agreement_id]) { _1.contract_terms_changed(terms: terms) }
    end

    def contract_discount_applied(terms:)
      with_negotiation(terms[:agreement_id]) { _1.contract_discount_applied(terms: terms) }
    end

    def conclude(terms:)
      with_negotiation(terms[:agreement_id]) { _1.conclude(terms: terms) }
    end

    private

    def with_negotiation(agreement_id, &)
      ActiveRecord::Base.transaction do
        AggregateRoot::Repository.new(Rails.configuration.event_store)
                                 .with_aggregate(Internal::Negotiation.new(agreement_id), "Negotiations::Negotiation$#{agreement_id}", &)
      end
    end
  end
end
