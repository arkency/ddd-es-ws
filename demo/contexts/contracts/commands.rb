# frozen_string_literal: true

module Contracts
  # Public entry point: one line per vertical slice. Negotiations calls change_price/change_hours
  # through here; the aggregate and the slices stay unpublished.
  module Commands
    extend self

    def request_quote(...) = RequestQuote::Handler.new.call(RequestQuote::Command.new(...))
    def create_draft(...) = CreateDraft::Handler.new.call(CreateDraft::Command.new(...))
    def send_draft(...) = SendDraft::Handler.new.call(SendDraft::Command.new(...))
    def change_price(...) = ChangePrice::Handler.new.call(ChangePrice::Command.new(...))
    def change_hours(...) = ChangeHours::Handler.new.call(ChangeHours::Command.new(...))
    def apply_discount(...) = ApplyDiscount::Handler.new.call(ApplyDiscount::Command.new(...))
    def generate(...) = Generate::Handler.new.call(Generate::Command.new(...))
    def sign(...) = Sign::Handler.new.call(Sign::Command.new(...))
  end
end
