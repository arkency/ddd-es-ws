# frozen_string_literal: true

module Inventory
  module AddConferenceRoom
    Command = Data.define(:name, :capacity) do
      def initialize(name:, capacity:) = super(name: name, capacity: Integer(capacity))
    end
  end
end
