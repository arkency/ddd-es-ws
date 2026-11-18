# frozen_string_literal: true

# The context map, in code. Every line of the diagram is one Edge here.
#
#   OHS/PL upstream  -> it publishes events from <Upstream>::Public;
#                       downstream subscribes an async IntegrationJob (ACL or Conformist).
#   OHS only         -> it exposes a synchronous facade (<Upstream>::Public);
#                       downstream calls it in-process. No events cross that edge.
#
# Private events live directly in the context namespace (<Context>::SomethingHappened)
# and are never referenced from another context.
#
# Downstream integrations live in contexts/<downstream>/integrations/<upstream>_<acl|conformist>.rb
#
# Flipping an upstream/downstream relationship (next workshop step) = changing an Edge
# here and moving the translation file to the other side. Nothing else in the contexts
# should need to know.
module ContextMap
  Edge = Data.define(:upstream, :upstream_role, :downstream, :downstream_role, :integration, :events) do
    def transport = events.empty? ? "sync facade" : "async events"
    def id = "#{upstream}->#{downstream}"
  end

  EDGES = [
    Edge.new("Contracts", "OHS/PL", "Negotiations", "Conformist",
             Negotiations::Integrations::ContractsConformist,
             [Contracts::Public::DraftAgreementSent,
              Contracts::Public::AgreementTermsChanged,
              Contracts::Public::DiscountApplied,
              Contracts::Public::AgreementSigned]),
    Edge.new("Contracts", "OHS/PL", "Reservations", "ACL",
             Reservations::Integrations::ContractsAcl,
             [Contracts::Public::AgreementSigned]),
    Edge.new("Contracts", "OHS/PL", "Invoicing", "ACL",
             Invoicing::Integrations::ContractsAcl,
             [Contracts::Public::AgreementSigned]),
    Edge.new("Inventory", "OHS/PL", "Pricing", "Conformist",
             Pricing::Integrations::InventoryConformist,
             [Inventory::Public::ResourceAdded,
              Inventory::Public::ResourceTakenOutOfService,
              Inventory::Public::ResourceRemoved]),
    Edge.new("Inventory", "OHS/PL", "Reservations", "ACL",
             Reservations::Integrations::InventoryAcl,
             [Inventory::Public::ResourceAdded,
              Inventory::Public::ResourceTakenOutOfService,
              Inventory::Public::ResourceRemoved]),
    Edge.new("Inventory", "OHS/PL", "Availability", "ACL",
             Availability::Integrations::InventoryAcl,
             [Inventory::Public::ResourceHoursAdded,
              Inventory::Public::ResourceTakenOutOfService,
              Inventory::Public::ResourceRemoved]),
    Edge.new("Pricing", "OHS/PL", "Reservations", "ACL",
             Reservations::Integrations::PricingAcl,
             [Pricing::Public::PricingAssigned]),
    Edge.new("Availability", "OHS", "Reservations", "Conformist",
             Reservations::Integrations::AvailabilityConformist,
             []),
    Edge.new("Payments", "OHS/PL", "Reservations", "ACL",
             Reservations::Integrations::PaymentsAcl,
             [Payments::Public::PaymentReceived,
              Payments::Public::PaymentTimedOut]),
    Edge.new("Payments", "OHS/PL", "Invoicing", "ACL",
             Invoicing::Integrations::PaymentsAcl,
             [Payments::Public::PaymentReceived]),
    Edge.new("Reservations", "OHS/PL", "Invoicing", "ACL",
             Invoicing::Integrations::ReservationsAcl,
             [Reservations::Public::ReservationConfirmed]),
    Edge.new("Reservations", "OHS/PL", "FacilityAccess", "ACL",
             FacilityAccess::Integrations::ReservationsAcl,
             [Reservations::Public::ReservationConfirmed]),
  ].freeze

  CONTEXTS = [Inventory, Pricing, Availability, Reservations, Payments, Invoicing, FacilityAccess, Contracts, Negotiations].freeze

  def self.wire(event_store)
    # Inside a context: synchronous projections of its own events.
    CONTEXTS.each { |context| context.subscribe_internal(event_store) if context.respond_to?(:subscribe_internal) }

    # Across contexts: asynchronous integration jobs.
    EDGES.reject { |edge| edge.events.empty? }.each do |edge|
      event_store.subscribe(edge.integration, to: edge.events)
    end
  end

  def self.edge_for(integration_name)
    EDGES.find { |edge| edge.integration.name == integration_name }
  end
end
