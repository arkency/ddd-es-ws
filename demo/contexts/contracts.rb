# frozen_string_literal: true

# Contracts: conference room agreements -- quote request, draft, terms, discount, DocuWare document, signature.
# Context map: OHS/PL upstream of Negotiations (Conformist), Reservations (ACL), Invoicing (ACL).
#
# Events defined here are private. Events other contexts may use live in Contracts::Public.
module Contracts
  QuoteRequested = Class.new(RubyEventStore::Event)        # client's request: agreed terms, no price yet
  DraftAgreementCreated = Class.new(RubyEventStore::Event) # full terms
  AgreementGenerated = Class.new(RubyEventStore::Event)    # agreement_id, document_id

  def self.subscribe_internal(event_store)
    event_store.subscribe(
      ReadModels::Projection.new,
      to: [
        QuoteRequested,
        DraftAgreementCreated,
        AgreementGenerated,
        Public::DraftAgreementSent,
        Public::AgreementTermsChanged,
        Public::DiscountApplied,
        Public::AgreementSigned,
      ],
    )
  end
end
