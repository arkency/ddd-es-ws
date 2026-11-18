# frozen_string_literal: true

module Negotiations
  # Public entry point: one line per vertical slice. Proposed/accepted terms are kept in
  # Contracts' own shape (Conformist); accepting a proposal goes through Contracts' Commands.
  module Commands
    extend self

    def propose_price_change(...) = ProposePriceChange::Handler.new.call(ProposePriceChange::Command.new(...))
    def propose_hours_change(...) = ProposeHoursChange::Handler.new.call(ProposeHoursChange::Command.new(...))
    def reject_proposal(...) = RejectProposal::Handler.new.call(RejectProposal::Command.new(...))
    def accept_proposal(...) = AcceptProposal::Handler.new.call(AcceptProposal::Command.new(...))
    def abandon(...) = Abandon::Handler.new.call(Abandon::Command.new(...))
    def open(...) = Open::Handler.new.call(Open::Command.new(...))
    def contract_terms_changed(...) = ContractTermsChanged::Handler.new.call(ContractTermsChanged::Command.new(...))
    def contract_discount_applied(...) = ContractDiscountApplied::Handler.new.call(ContractDiscountApplied::Command.new(...))
    def conclude(...) = Conclude::Handler.new.call(Conclude::Command.new(...))
  end
end
