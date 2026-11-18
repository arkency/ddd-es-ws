# frozen_string_literal: true

require_relative "test_helper"

# The scenario catalog is executable documentation: every scenario must run through the real
# commands and end with all of its own checks passing.
class ScenariosTest < DemoTest
  def test_every_scenario_reaches_its_checks
    Scenarios::ALL.each do |scenario|
      start_from_scratch
      runner = ScenarioRunner.new(scenario)
      runner.start

      until runner.finished?
        definition = runner.next_step
        runner.step!
        deliver(definition)
        runner.wait!
      end

      results = runner.checks
      assert_equal scenario.checks.size, results.size
      failures = results.reject { |_, result| result == "passed" }
      assert_empty failures, "#{scenario.key} failed its checks:\n#{failures.map(&:first).join("\n")}"
    ensure
      ScenarioFault.disarm
      clear_enqueued_jobs
    end
  end

  private

  def start_from_scratch
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
      connection.execute("DELETE FROM #{table}")
    end
    clear_enqueued_jobs
  end

  # Mirrors the :async adapter: keep delivering until nothing is queued. A faulted edge is
  # supposed to blow up, so that one exception is expected; the rest must still be delivered.
  def deliver(definition)
    until enqueued_jobs.empty?
      begin
        perform_enqueued_jobs
      rescue ScenarioFault::DownstreamDown
        raise unless definition.fault
      end
    end
  end
end
