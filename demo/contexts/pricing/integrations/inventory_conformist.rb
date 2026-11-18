# frozen_string_literal: true

module Pricing
  module Integrations
    # CONFORMIST: Pricing adopts Inventory's model as-is.
    #
    # No translation: same ids, same resource_type, same attributes (zone, capacity), same status
    # vocabulary ("available", "out_of_service", "removed"). Pricing's table mirrors Inventory's.
    # Conformance stops at the table: Pricing still publishes its own generic PricingAssigned
    # (resource_id, resource_type, price_cents, price_unit), not Inventory's events.
    #
    # Cheap today. The price: any change in Inventory's Published Language ripples straight
    # into Pricing's code, table and Published Language.
    class InventoryConformist < IntegrationJob
      def call(event)
        data = event.data
        case event
        when Inventory::Public::ResourceAdded
          ReadModels::Resource.find_or_initialize_by(resource_id: data[:resource_id]).update!(
            resource_type: data[:resource_type], name: data[:name],
            zone: data[:zone], capacity: data[:capacity], status: "available",
          )
        when Inventory::Public::ResourceTakenOutOfService
          ReadModels::Resource.find(data[:resource_id]).update!(status: "out_of_service")
        when Inventory::Public::ResourceRemoved
          ReadModels::Resource.find(data[:resource_id]).update!(status: "removed")
        end
      end
    end
  end
end
