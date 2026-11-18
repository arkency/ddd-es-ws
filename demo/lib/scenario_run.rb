# frozen_string_literal: true

# Presentation aid: the scenario run behind the Scenarios page. Holds the run's correlation id
# (every event published by its steps carries it), the next step, ids returned by earlier steps
# (so later steps can refer to them) and the per-step log shown in the UI.
class ScenarioRun < ActiveRecord::Base
  def step_log = steps || []
  def step_results = (results || {}).symbolize_keys
end
