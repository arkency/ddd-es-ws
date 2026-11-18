# frozen_string_literal: true

# Presentation aid, next to SlowMotion: "make this downstream context fail on the next delivery".
# Armed by the scenario runner, read by every IntegrationJob in its own thread.
# Deliberately not a domain concept: nothing in a context knows scenarios exist.
module ScenarioFault
  DownstreamDown = Class.new(StandardError)

  mattr_accessor :integration, default: nil
  mattr_accessor :fired, default: false

  def self.arm(integration_name)
    self.integration = integration_name
    self.fired = false
  end

  def self.disarm
    self.integration = nil
    self.fired = false
  end

  def self.raise_if_armed!(integration_name)
    return unless integration == integration_name

    self.fired = true
    raise DownstreamDown, "scenario fault: #{integration_name} is down"
  end
end
