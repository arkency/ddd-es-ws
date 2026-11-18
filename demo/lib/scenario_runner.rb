# frozen_string_literal: true

# Executes the steps of a Scenarios::Scenario against the real Commands, one at a time.
#
# - Each step publishes under the run's correlation id, so the feed and /res can show exactly
#   this run's causal chain (with_metadata is the same mechanism CorrelatedHandler extends).
# - A step can wait for its events to be delivered to every subscribed context (IntegrationLog),
#   so the next step never races an edge that has not arrived yet.
# - A faulted step waits until the fault has actually fired, instead of assuming it did.
# - Results of earlier steps (ids) are stored on the run and passed to later steps' lambdas.
class ScenarioRunner
  class Finished < StandardError; end
  class DeliveryTimeout < StandardError; end

  WAIT_TIMEOUT = 20
  POLL = 0.05

  # Two clicks (or two tabs) must not run the same step twice. One presenter, one run at a time.
  LOCK = Mutex.new
  def self.exclusive(&block) = LOCK.synchronize(&block)

  attr_reader :scenario, :run

  def self.for(scenario) = ScenarioRun.where(scenario_key: scenario.key).order(:created_at).last

  def initialize(scenario)
    @scenario = scenario
    @run = self.class.for(scenario) || open_run
  end

  # Wipes this scenario's previous runs and opens a fresh one. Does not touch read models.
  def start
    open_run
    self
  end

  def open_run
    @run = ScenarioRun.create!(
      id: SecureRandom.uuid,
      scenario_key: scenario.key,
      correlation_id: "run_#{SecureRandom.hex(3)}",
      next_step: 0, results: {}, steps: [],
    )
  end

  def finished? = run.next_step >= scenario.steps.size
  def next_step = scenario.steps[run.next_step]
  def results = run.step_results

  # Executes the next step and records it. Returns the record for the step.
  def step!
    raise Finished, "#{scenario.key} is finished" if finished?

    definition = next_step
    index = run.next_step
    args = definition.resolved_args(results)
    known = run_event_ids
    started = monotonic
    error = nil
    result = nil
    ScenarioFault.arm(definition.fault) if definition.fault

    begin
      result = event_store.with_metadata(correlation_id: run.correlation_id) do
        CommandApi.call(context: definition.context, command: definition.command, args: args)
      end
    rescue StandardError => e
      raise unless definition.expect_error && e.class.name == definition.expect_error

      error = "#{e.class}: #{e.message}"
    end

    produced = (run_event_ids - known).map { |id| event_store.read.event(id) }.compact
    record = {
      "index" => index,
      "status" => error ? "expected_error" : "ok",
      "error" => error,
      "ms" => ((monotonic - started) * 1000).round,
      "args" => args.transform_values(&:to_s),
      "events" => produced.map { |event| { "id" => event.event_id, "type" => event.event_type } },
    }
    run.update!(
      next_step: index + 1,
      results: definition.key ? run.results.to_h.merge(definition.key.to_s => result) : run.results.to_h,
      steps: run.step_log + [record],
    )
    record
  end

  # Waits until the step just executed is visible where it is supposed to be visible.
  # Raises DeliveryTimeout rather than silently moving on, so a presenter sees the problem.
  def wait!(timeout: WAIT_TIMEOUT)
    definition = scenario.steps[run.next_step - 1] or return
    deadline = monotonic + timeout

    loop do
      events = run_events
      missing = definition.wait_for - events.map(&:event_type)
      waited_ids = events.select { |event| definition.wait_for.include?(event.event_type) }.map(&:event_id)
      pending = definition.wait_deliveries ? undelivered(waited_ids) : []
      fault_pending = definition.fault && !ScenarioFault.fired

      return if missing.empty? && pending.empty? && !fault_pending

      if monotonic > deadline
        reason =
          if missing.any?
            missing.map { |type| type.split("::").last }.join(" + ")
          else
            "delivery to #{(pending.map(&:integration) + [definition.fault]).compact.uniq.join(", ")}"
          end
        raise DeliveryTimeout, "step #{run.next_step} timed out waiting for #{reason}"
      end

      sleep POLL
    end
  end

  def checks
    return [] unless finished?

    scenario.checks.map { |label, check| [label, check.call ? "passed" : "failed"] }
  end

  private

  def event_store = Rails.configuration.event_store

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # The run's events, oldest first. Small demo store; a real one would query by correlation id.
  # uncached: within one request the polling loop must see what other threads have committed.
  def run_events
    ActiveRecord::Base.uncached do
      event_store.read.backward.limit(1_000).to_a
                  .select { |event| event.metadata[:correlation_id] == run.correlation_id }
                  .reverse
    end
  end

  def run_event_ids = run_events.map(&:event_id)

  def undelivered(event_ids)
    return [] if event_ids.empty?

    ActiveRecord::Base.uncached do
      scope = IntegrationLog.where(event_id: event_ids, handled_at: nil)
      scope = scope.where.not(integration: ScenarioFault.integration) if ScenarioFault.integration
      scope.to_a
    end
  end
end
