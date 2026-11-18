# frozen_string_literal: true

module Negotiations
  module Internal
    # Identified by Contracts' agreement_id and holding Contracts' terms hash as-is: conformist.
    class Negotiation
      include AggregateRoot

      NotOpen = Class.new(StandardError)
      ProposalPending = Class.new(StandardError)
      NoProposal = Class.new(StandardError)

      def initialize(agreement_id)
        @agreement_id = agreement_id
        @status = :new
      end

      def open(terms:)
        raise NotOpen, "negotiation #{@agreement_id} already started" unless @status == :new

        apply NegotiationOpened.new(data: { agreement_id: @agreement_id, terms: terms })
      end

      def propose_price_change(price_cents:, proposed_by:)
        require_open_without_proposal
        apply PriceChangeProposed.new(data: { agreement_id: @agreement_id, proposed_by: proposed_by, price_cents: price_cents })
      end

      def propose_hours_change(from_hour:, to_hour:, proposed_by:)
        require_open_without_proposal
        apply AvailabilityHoursChangeProposed.new(
          data: { agreement_id: @agreement_id, proposed_by: proposed_by, from_hour: from_hour, to_hour: to_hour },
        )
      end

      def reject_proposal
        require_proposal
        rejected = @proposal == :price ? PriceChangeRejected : AvailabilityHoursChangeRejected
        apply rejected.new(data: { agreement_id: @agreement_id })
      end

      # Contracts changed the terms. If that is what we proposed, the proposal got accepted.
      def contract_terms_changed(terms:)
        require_open
        accepted =
          case [@proposal, terms[:changed]]
          in [:price, "price"] then PriceChangeAccepted
          in [:hours, "hours"] then AvailabilityHoursChangeAccepted
          else TermsChanged
          end
        apply accepted.new(data: { agreement_id: @agreement_id, terms: terms })
      end

      def contract_discount_applied(terms:)
        require_open
        apply DiscountApplied.new(data: { agreement_id: @agreement_id, terms: terms })
      end

      def conclude(terms:)
        require_open
        apply NegotiationsConcluded.new(data: { agreement_id: @agreement_id, terms: terms })
      end

      def abandon(reason:, client_name:)
        require_open
        apply NegotiationsProcessAbandoned.new(data: { agreement_id: @agreement_id, reason: reason })
        apply ClientLost.new(data: { agreement_id: @agreement_id, client_name: client_name })
      end

      private

      def require_open
        raise NotOpen, "negotiation #{@agreement_id} is #{@status}" unless @status == :open
      end

      def require_open_without_proposal
        require_open
        raise ProposalPending, "a #{@proposal} change is already on the table" if @proposal
      end

      def require_proposal
        require_open
        raise NoProposal, "nothing proposed" unless @proposal
      end

      on NegotiationOpened do |_event|
        @status = :open
      end

      on PriceChangeProposed do |_event|
        @proposal = :price
      end

      on AvailabilityHoursChangeProposed do |_event|
        @proposal = :hours
      end

      [PriceChangeRejected, AvailabilityHoursChangeRejected, PriceChangeAccepted, AvailabilityHoursChangeAccepted].each do |closes_proposal|
        on closes_proposal do |_event|
          @proposal = nil
        end
      end

      on TermsChanged do |_event|
      end

      on DiscountApplied do |_event|
      end

      on NegotiationsConcluded do |_event|
        @status = :concluded
      end

      on NegotiationsProcessAbandoned do |_event|
        @status = :abandoned
      end

      on ClientLost do |_event|
      end
    end
  end
end
