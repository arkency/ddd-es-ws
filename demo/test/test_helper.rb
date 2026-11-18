# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "minitest/autorun"
require "active_support/test_case"

load Rails.root.join("db/schema.rb")

class DemoTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).each { |table| connection.execute("DELETE FROM #{table}") }
  end

  # Run cross-context jobs until nothing is left: what the :async adapter does in the background.
  def deliver_async_events
    perform_enqueued_jobs until enqueued_jobs.empty?
  end

  def event_store = Rails.configuration.event_store
end
