# frozen_string_literal: true

# Presentation aid, not a domain concept: what crossed which edge of the context map, when,
# and which read-model tables the delivery wrote.
# A row with enqueued_at but no handled_at is an event still travelling to its downstream context.
class IntegrationLog < ActiveRecord::Base
  scope :in_transit, -> { where(handled_at: nil) }

  def self.enqueued(integration:, event_id:, message:)
    find_or_initialize_by(integration: integration, event_id: event_id).update!(message: message, enqueued_at: Time.current)
  end

  def self.record(integration:, message:, event: nil, tables: [])
    log = find_or_initialize_by(integration: integration, event_id: event&.event_id || SecureRandom.uuid)
    log.update!(message: message, published_at: event&.metadata&.fetch(:timestamp, nil), handled_at: Time.current, tables: tables.join(","))
  end

  def read_models = tables.to_s.split(",")

  def in_transit? = handled_at.nil?

  def latency_ms
    published_at && handled_at && ((handled_at - published_at) * 1000).round
  end
end
