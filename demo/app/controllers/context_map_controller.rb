# frozen_string_literal: true

class ContextMapController < ApplicationController
  before_action :load_traffic

  def show; end

  # The map alone, polled by the page.
  def live
    render partial: "context_map/map", layout: false
  end

  private

  def load_traffic
    @edges = ContextMap::EDGES
    @logs_by_integration = IntegrationLog.order(id: :desc).limit(1000).group_by(&:integration)
  end
end
