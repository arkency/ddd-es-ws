# frozen_string_literal: true

module Contracts
  module Commands
    extend self

    def request_quote(client_name:, company:, tax_id:, room_id:, date:, from_hour:, to_hour:)
      agreement_id = SecureRandom.uuid
      with_agreement(agreement_id) do |agreement|
        agreement.request_quote(
          client_name: client_name, company: company, tax_id: tax_id, room_id: room_id, date: Date.iso8601(date.to_s),
          from_hour: Integer(from_hour), to_hour: Integer(to_hour),
        )
      end
      agreement_id
    end

    def create_draft(agreement_id:, price_cents:)
      with_agreement(agreement_id) { |agreement| agreement.create_draft(price_cents: Integer(price_cents)) }
    end

    def send_draft(agreement_id:)
      with_agreement(agreement_id, &:send_to_client)
    end

    def change_price(agreement_id:, price_cents:)
      with_agreement(agreement_id) { |agreement| agreement.change_price(price_cents: Integer(price_cents)) }
    end

    def change_hours(agreement_id:, from_hour:, to_hour:)
      with_agreement(agreement_id) { |agreement| agreement.change_hours(from_hour: Integer(from_hour), to_hour: Integer(to_hour)) }
    end

    def apply_discount(agreement_id:, percent:)
      with_agreement(agreement_id) { |agreement| agreement.apply_discount(percent: Integer(percent)) }
    end

    def generate(agreement_id:)
      document_id = External::DocuWare.generate(agreement_id: agreement_id)
      with_agreement(agreement_id) { |agreement| agreement.generate(document_id: document_id) }
    end

    def sign(agreement_id:)
      with_agreement(agreement_id, &:sign)
    end

    private

    def with_agreement(id, &)
      ActiveRecord::Base.transaction do
        AggregateRoot::Repository.new(Rails.configuration.event_store)
                                 .with_aggregate(Internal::Agreement.new(id), "Contracts::Agreement$#{id}", &)
      end
    end
  end
end
