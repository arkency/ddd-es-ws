# frozen_string_literal: true

module Reservations
  module RegisterResource
    # One Inventory event, two possible tables: resource_type decides. Async, so the row may
    # already exist (upsert) or arrive later (SetRate tolerates both orders).
    Command = Data.define(:resource_id, :resource_type, :name, :zone, :capacity) do
      def initialize(resource_id:, resource_type:, name:, zone: nil, capacity: nil)
        super(resource_id: resource_id, resource_type: resource_type, name: name, zone: zone, capacity: capacity)
      end
    end
  end
end
