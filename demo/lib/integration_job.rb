# frozen_string_literal: true

# Base class for every cross-context subscriber: each ACL and Conformist on an OHS/PL edge.
#
# - async: RES enqueues it after the upstream transaction commits, so a failing
#   downstream never rolls back (or even slows down) the upstream.
# - own transaction: translation + downstream command + log commit together.
# - correlated: events published downstream carry correlation/causation ids of the
#   upstream event (see the RES browser at /res).
# - read models: the log records which tables the delivery wrote (ReadModelTracker).
# - slow motion: for the presentation, every delivery can be delayed (SlowMotion.seconds)
#   so you can watch events travel between contexts.
#
# Subclasses implement `call(event)`.
class IntegrationJob < ActiveJob::Base
  prepend RailsEventStore::CorrelatedHandler
  prepend RailsEventStore::AsyncHandler.with(event_store: nil, event_store_locator: -> { Rails.configuration.event_store })

  after_enqueue do |job|
    payload = job.arguments.first
    IntegrationLog.enqueued(integration: job.class.name, event_id: payload.fetch("event_id"), message: payload.fetch("event_type"))
  end

  def perform(event)
    sleep(SlowMotion.seconds) if SlowMotion.seconds.positive?
    ScenarioFault.raise_if_armed!(self.class.name)
    ActiveRecord::Base.transaction do
      _, tables = ReadModelTracker.track { call(event) }
      IntegrationLog.record(integration: self.class.name, message: event.event_type, event: event, tables: tables)
    end
  end
end
