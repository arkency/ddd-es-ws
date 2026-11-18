# frozen_string_literal: true

module Pricing
  # Public entry point: one line per vertical slice.
  module Commands
    extend self

    def assign_pricing(...) = AssignPricing::Handler.new.call(AssignPricing::Command.new(...))
  end
end
