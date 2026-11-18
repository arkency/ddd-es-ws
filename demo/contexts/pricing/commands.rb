# frozen_string_literal: true

module Pricing
  module Commands
    extend self

    CannotPrice = Class.new(StandardError)

    # One command for every resource. The unit follows the resource type Pricing already knows:
    # a desk is priced per day, a conference room per hour. No desk_id/room_id split.
    def assign_pricing(resource_id:, price_cents:)
      price = Integer(price_cents)
      ActiveRecord::Base.transaction do
        resource = ReadModels::Resource.find_by(resource_id: resource_id)
        raise CannotPrice, "Inventory has no available resource #{resource_id}" unless resource&.status == "available"

        unit = resource.resource_type == "desk" ? "day" : "hour"
        resource.update!(price_cents: price, price_unit: unit)
        publish(
          Public::PricingAssigned.new(
            data: { resource_id: resource_id, resource_type: resource.resource_type,
                    price_cents: price, price_unit: unit },
          ),
        )
      end
    end

    private

    def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "Pricing")
  end
end
