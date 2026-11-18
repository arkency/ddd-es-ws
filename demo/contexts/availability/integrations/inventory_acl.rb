# frozen_string_literal: true

module Availability
  module Integrations
    # ANTI-CORRUPTION LAYER over Inventory.
    #
    # Inventory owns the availability hours of its resources and validates them. Availability
    # knows neither desks nor rooms: only resources with opening hours. This ACL records the
    # hours Inventory publishes on the Resource, and forgets them when the resource is removed
    # or taken out of service.
    class InventoryAcl < IntegrationJob
      def call(event)
        data = event.data
        case event
        when Inventory::Public::ResourceHoursAdded
          Internal::Resources.record_opening_hours(
            resource_id: data[:resource_id],
            opens_at_hour: data[:opens_at_hour],
            closes_at_hour: data[:closes_at_hour],
          )
        when Inventory::Public::ResourceRemoved, Inventory::Public::ResourceTakenOutOfService
          Internal::Resources.forget_opening_hours(resource_id: data[:resource_id])
        end
      end
    end
  end
end
