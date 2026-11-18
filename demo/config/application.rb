# frozen_string_literal: true

require "bundler/setup"
require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "rails_event_store"
require "aggregate_root"

module Demo
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.secret_key_base = "workshop-demo-not-a-secret"
    config.logger = Logger.new($stdout) unless Rails.env.test?
    config.log_level = :warn

    # No reloading: one event store, one set of subscriptions for the whole process.
    config.enable_reloading = false
    config.eager_load = true

    # contexts/<bounded_context>/... => <BoundedContext>::...
    config.autoload_paths += [root.join("contexts"), root.join("lib")]
    config.eager_load_paths += [root.join("contexts"), root.join("lib")]

    # Cross-context handlers are ActiveJobs. :async runs them on in-process threads,
    # so the demo needs no Redis/Sidekiq, but they are still really asynchronous.
    config.active_job.queue_adapter = Rails.env.test? ? :test : :async

    config.after_initialize do
      ReadModelTracker.install
      load root.join("db/schema.rb") unless ActiveRecord::Base.connection.table_exists?(:event_store_events)

      event_store = RailsEventStore::JSONClient.new
      config.event_store = event_store

      load root.join("config/context_map.rb")
      load root.join("config/scenarios.rb")
      ContextMap.wire(event_store)
    end
  end
end
