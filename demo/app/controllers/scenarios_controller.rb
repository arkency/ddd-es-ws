# frozen_string_literal: true

# The Scenarios page: a library of predefined runs next to the dashboard. Every button here
# ends up in the same CommandApi the dashboard uses; nothing domain-specific lives in this file.
class ScenariosController < ApplicationController
  def index
    @scenarios = Scenarios::ALL
    @scenario = Scenarios.find(params[:scenario])
    @runner = ScenarioRunner.new(@scenario)
    @run = @runner.run
    @log = @run.step_log
    @checks = @runner.checks
    @next_definition = @runner.finished? ? nil : @runner.next_step
    @next_args = display_args(@runner, @next_definition)
    @feed_correlation_id = @run.correlation_id
    @feed_scope = "this run"
  end

  def step
    execute("Step") do |runner|
      runner.step!
      runner.wait!
    end
  end

  def run_all
    execute("Scenario") do |runner|
      until runner.finished?
        runner.step!
        runner.wait!
      end
    end
  end

  # Fresh run for this scenario. Read models and the event store stay as they are.
  def start
    runner = ScenarioRunner.new(scenario)
    runner.start
    flash[:notice] = "Started a fresh run (#{runner.run.correlation_id})."
    redirect_to scenarios_path(scenario: scenario.key)
  end

  # Wipes events and read models first, so the run's ids and counts match the script.
  def reset
    ScenarioRun.delete_all
    load Rails.root.join("db/schema.rb")
    runner = ScenarioRunner.new(scenario)
    runner.start
    flash[:notice] = "Database reset. New run #{runner.run.correlation_id}."
    redirect_to scenarios_path(scenario: scenario.key)
  end

  private

  def scenario = @scenario ||= Scenarios.find(params[:scenario])

  def execute(label)
    runner = ScenarioRunner.new(scenario)
    ScenarioRunner.exclusive do
      yield runner
    end
    flash[:notice] = "#{label} finished — #{runner.run.next_step}/#{scenario.steps.size} steps."
  rescue ScenarioRunner::Finished
    flash[:alert] = "This run is already finished. Use “Start over” or “Reset & run”."
  rescue StandardError => e
    flash[:alert] = "#{label} failed — #{e.class}: #{e.message}"
  ensure
    ScenarioFault.disarm
    redirect_to scenarios_path(scenario: scenario.key)
  end

  # Only the next step's args are resolvable; later steps still reference ids that do not exist.
  def display_args(runner, definition)
    return {} unless definition

    definition.resolved_args(runner.results)
  rescue StandardError
    {}
  end
end
