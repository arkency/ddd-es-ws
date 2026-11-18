# frozen_string_literal: true

module Contracts
  # Every event carries the full current terms of the agreement:
  #   agreement_id, client_name, company, tax_id, room_id, date, from_hour, to_hour,
  #   price_cents, discount_percent, total_cents
  # AgreementTermsChanged additionally carries `changed` ("price" | "hours").
  module Public
    DraftAgreementSent = Class.new(RubyEventStore::Event)
    AgreementTermsChanged = Class.new(RubyEventStore::Event)
    DiscountApplied = Class.new(RubyEventStore::Event)
    AgreementSigned = Class.new(RubyEventStore::Event)
  end
end
