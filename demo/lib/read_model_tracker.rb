# frozen_string_literal: true

# Presentation aid: which read-model tables a unit of work wrote to. Every INSERT/UPDATE/DELETE
# that runs inside ReadModelTracker.track is attributed to its table. Event store tables and the
# integration log are not read models, so they are ignored.
module ReadModelTracker
  KEY = :read_model_writes
  WRITE = /\A\s*(INSERT|UPDATE|DELETE)\b/i
  TABLE = /\b(?:INTO|UPDATE|FROM)\s+"?(\w+)"?/i
  NOT_READ_MODELS = /\A(event_store_|integration_logs|outbox_messages|schema_migrations|ar_internal_metadata)/

  # Runs the block and returns [result, sorted table names written while it ran].
  # Nested calls report only their own writes; the outer call still sees all of them.
  def self.track
    outer = Thread.current[KEY]
    writes = outer || []
    Thread.current[KEY] = writes
    from = writes.size
    result = yield
    [result, writes[from..].uniq.sort]
  ensure
    Thread.current[KEY] = outer
  end

  def self.install
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      writes = Thread.current[KEY]
      payload = args.last
      next unless writes && payload[:sql].match?(WRITE)

      table = payload[:sql][TABLE, 1]
      writes << table if table && !table.match?(NOT_READ_MODELS)
    end
  end
end
