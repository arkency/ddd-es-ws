# frozen_string_literal: true

module Reservations
  module Integrations
    # ANTI-CORRUPTION LAYER over Pricing.
    #
    # Pricing speaks generically: a *resource* with an amount and a unit. We fold that into
    # our own concept: a *tariff* (rate + unit) on one of the two inventory projections.
    class PricingAcl < IntegrationJob
      def call(event)
        data = event.data
        case event
        when Pricing::Public::PricingAssigned
          Commands.set_rate(resource_id: data[:resource_id], resource_type: data[:resource_type],
                            rate_cents: data[:price_cents], rate_unit: data[:price_unit])
        end
      end
    end
  end
end
