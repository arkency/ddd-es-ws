# frozen_string_literal: true

module Pricing
  module AssignPricing
    # One command for every resource. The unit follows the resource type Pricing already knows:
    # a desk is priced per day, a conference room per hour. No desk_id/room_id split.
    Command = Data.define(:resource_id, :price_cents) do
      def initialize(resource_id:, price_cents:) = super(resource_id: resource_id, price_cents: Integer(price_cents))
    end
  end
end
