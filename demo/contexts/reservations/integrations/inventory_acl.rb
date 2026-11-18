# frozen_string_literal: true

module Reservations
  module Integrations
    # ANTI-CORRUPTION LAYER over Inventory.
    #
    # Inventory publishes generic resources with a resource_type. Reservations keeps two
    # projections, one per type, because that is the shape its commands want (a desk offer
    # takes the whole opening hours; a room comes from a signed agreement). The ACL forwards
    # the generic event and Reservations' own command routes it on resource_type.
    #
    # Translation happens here: Inventory's "removed" and "out of service" both mean the same
    # thing to us: withdrawn.
    class InventoryAcl < IntegrationJob
      def call(event)
        data = event.data
        case event
        when Inventory::Public::ResourceAdded
          Commands.register_resource(
            resource_id: data[:resource_id], resource_type: data[:resource_type],
            name: data[:name], zone: data[:zone], capacity: data[:capacity],
          )
        when Inventory::Public::ResourceRemoved, Inventory::Public::ResourceTakenOutOfService
          Commands.withdraw_resource(resource_id: data[:resource_id])
        end
      end
    end
  end
end
