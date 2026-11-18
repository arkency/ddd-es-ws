# frozen_string_literal: true

# Side panel: the latest events in the store and where each one is travelling. Polled by the layout.
class FeedController < ApplicationController
  def show
    @events = recent_events
    @deliveries = IntegrationLog.where(event_id: @events.map(&:event_id)).group_by(&:event_id)
    @types_by_id = @events.to_h { |event| [event.event_id, event.event_type] }
    render partial: "feed/feed", layout: false
  end

  private

  # On the Scenarios page the panel shows only the causal chain of the selected run.
  def recent_events
    correlation_id = params[:correlation_id].presence
    events = Rails.configuration.event_store.read.backward.limit(correlation_id ? 1_000 : 30).to_a
    return events if correlation_id.nil?

    events.select { |event| event.metadata[:correlation_id] == correlation_id }.first(30)
  end
end
