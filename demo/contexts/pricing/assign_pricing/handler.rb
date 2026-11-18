# frozen_string_literal: true

module Pricing
  module AssignPricing
    class Handler
      CannotPrice = Class.new(StandardError)

      def call(command)
        ActiveRecord::Base.transaction do
          resource = ReadModels::Resource.find_by(resource_id: command.resource_id)
          raise CannotPrice, "Inventory has no available resource #{command.resource_id}" unless resource&.status == "available"

          unit = resource.resource_type == "desk" ? "day" : "hour"
          resource.update!(price_cents: command.price_cents, price_unit: unit)
          Rails.configuration.event_store.publish(
            Public::PricingAssigned.new(
              data: { resource_id: command.resource_id, resource_type: resource.resource_type,
                      price_cents: command.price_cents, price_unit: unit },
            ),
            stream_name: "Pricing",
          )
        end
      end
    end
  end
end
