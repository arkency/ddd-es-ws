# frozen_string_literal: true

module Contracts
  module Internal
    class Agreement
      include AggregateRoot

      InvalidState = Class.new(StandardError)
      InvalidTerms = Class.new(StandardError)

      def initialize(id)
        @id = id
        @status = :new
      end

      # The client asks for a room. No price yet: the manager prices the quote.
      def request_quote(client_name:, company:, tax_id:, room_id:, date:, from_hour:, to_hour:)
        require_status(:new)
        raise InvalidTerms, "from_hour must be before to_hour" unless from_hour < to_hour

        apply QuoteRequested.new(
          data: { agreement_id: @id, client_name: client_name, company: company, tax_id: tax_id, room_id: room_id,
                  date: date, from_hour: from_hour, to_hour: to_hour },
        )
      end

      # The manager prices a requested quote and turns it into a draft.
      def create_draft(price_cents:)
        require_status(:requested)

        apply DraftAgreementCreated.new(data: terms_payload(price_cents: price_cents, discount_percent: 0))
      end

      def send_to_client
        require_status(:draft)
        apply Public::DraftAgreementSent.new(data: terms_payload)
      end

      def change_price(price_cents:)
        require_status(:sent)
        apply Public::AgreementTermsChanged.new(data: terms_payload(price_cents: price_cents).merge(changed: "price"))
      end

      def change_hours(from_hour:, to_hour:)
        require_status(:sent)
        raise InvalidTerms, "from_hour must be before to_hour" unless from_hour < to_hour

        apply Public::AgreementTermsChanged.new(
          data: terms_payload(from_hour: from_hour, to_hour: to_hour).merge(changed: "hours"),
        )
      end

      def apply_discount(percent:)
        require_status(:sent)
        raise InvalidTerms, "discount must be 1-50%" unless (1..50).cover?(percent)

        apply Public::DiscountApplied.new(data: terms_payload(discount_percent: percent))
      end

      def generate(document_id:)
        require_status(:sent)
        apply AgreementGenerated.new(data: { agreement_id: @id, document_id: document_id })
      end

      def sign
        require_status(:generated)
        apply Public::AgreementSigned.new(data: terms_payload)
      end

      private

      def require_status(expected)
        raise InvalidState, "agreement #{@id} is #{@status}, expected #{expected}" unless @status == expected
      end

      # Current terms with `changes` on top, plus the derived total.
      def terms_payload(**changes)
        terms = (@terms || {}).merge(changes)
        total = terms[:price_cents] * (100 - terms[:discount_percent]) / 100
        { agreement_id: @id, **terms.slice(*TERMS), total_cents: total }
      end

      TERMS = %i[client_name company tax_id room_id date from_hour to_hour price_cents discount_percent].freeze

      def remember_terms(event) = @terms = event.data.slice(*TERMS)

      on QuoteRequested do |event|
        @status = :requested
        remember_terms(event)
      end

      on DraftAgreementCreated do |event|
        @status = :draft
        remember_terms(event)
      end

      on Public::DraftAgreementSent do |_event|
        @status = :sent
      end

      on Public::AgreementTermsChanged do |event|
        remember_terms(event)
      end

      on Public::DiscountApplied do |event|
        remember_terms(event)
      end

      on AgreementGenerated do |_event|
        @status = :generated
      end

      on Public::AgreementSigned do |_event|
        @status = :signed
      end
    end
  end
end
