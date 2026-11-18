# frozen_string_literal: true

# Presentation knob: delay before every cross-context delivery, so events can be watched in transit.
# Process-wide and in memory (one Puma process); 0 means deliver as fast as possible.
module SlowMotion
  CHOICES = [0, 1, 2, 3, 5].freeze

  mattr_accessor :seconds, default: 0
end
