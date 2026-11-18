# frozen_string_literal: true

# "What should I click next?" derived from the read models, so the hint follows the
# dashboard's actual state instead of a fixed script.
#
# The order is the demo's happy path:
#   resource -> hours -> price -> pre-reserve -> pay -> confirm -> scan
#   -> room -> hours -> quote -> draft -> send -> generate -> sign
#   -> pay -> confirm -> scan
# Optional branches (photos, discounts, negotiations, timeouts) never block it.
module ProcessGuide
  Step = Data.define(:panel, :context, :command, :title, :hint, :args) do
    def panel_id = panel
    def panel_name = panel.split("_").map(&:capitalize).join(" ")
  end

  module_function

  def next_step
    desk_step || reservation_step || room_step || agreement_step
  end

  def desk_step
    desk = Inventory::ReadModels::Resource.where(resource_type: "desk", status: "available").order(:name).first
    return step("inventory", "inventory", "add_desk", "Add a desk",
                "Inventory publishes ResourceAdded with resource_type desk; Pricing and Reservations learn about it through the map.") unless desk

    if desk.opens_at_hour.nil?
      return step("inventory", "inventory", "add_availability_hours",
                  "Set opening hours for desk #{desk.name}",
                  "Availability records the hours through Inventory's ACL.",
                  resource_id: desk.id)
    end

    price = Pricing::ReadModels::Resource.find_by(resource_id: desk.id)
    if price.nil? || price.price_cents.nil?
      return step("pricing", "pricing", "assign_pricing",
                  "Price desk #{desk.name}",
                  "Pricing publishes PricingAssigned; Reservations turns it into a tariff.",
                  resource_id: desk.id, price_cents: 4_500)
    end

    return unless Reservations::ReadModels::Desk.where(withdrawn: false).where.not(rate_cents: nil).exists?
    return if Reservations::ReadModels::Reservation.exists?

    step("reservations", "reservations", "pre_reserve_desk", "Pre-reserve a desk",
         "Creates an offer and a temporary hold in Availability; the reservation waits for payment.")
  end

  def reservation_step
    pending = Payments::ReadModels::Payment.where(status: "pending").order(:reference).first
    if pending
      return step("payments", "payments", "gateway_confirmed", "Confirm the payment in the gateway",
                  "Simulates the callback; Payments publishes PaymentReceived to Reservations and Invoicing.",
                  payment_id: pending.id)
    end

    awaiting = Reservations::ReadModels::Reservation.where(status: "awaiting_payment").order(:date, :from_hour).to_a
    unpaid = awaiting.find do |reservation|
      !Payments::ReadModels::Payment.where(reference: reservation.id, status: %w[pending received]).exists?
    end
    if unpaid
      return step("reservations", "payments", "request_payment",
                  "Pay the reservation for #{unpaid.client} — #{unpaid.label}",
                  "Checkout asks Payments; the result comes back to Reservations and Invoicing as events.",
                  reference: unpaid.id)
    end

    pass = FacilityAccess::ReadModels::Pass.order(:valid_on, :id).detect do |candidate|
      !FacilityAccess::ReadModels::Scan.exists?(code: candidate.code, result: "accepted")
    end
    return unless pass

    step("facility_access", "facility_access", "scan",
         "Scan #{pass.holder}'s QR code for #{pass.zone}",
         "Valid on #{pass.valid_on}, #{pass.from_hour}:00-#{pass.to_hour}:00.")
  end

  def room_step
    room = Inventory::ReadModels::Resource.where(resource_type: "conference_room", status: "available").order(:name).first
    return step("inventory", "inventory", "add_conference_room", "Add a conference room",
                "Contracts needs a room before it can quote one.") unless room
    return unless room.opens_at_hour.nil?

    step("inventory", "inventory", "add_availability_hours",
         "Set opening hours for #{room.name}",
         "Availability records the room's hours through Inventory's ACL.",
         resource_id: room.id)
  end

  def agreement_step
    agreements = Contracts::ReadModels::Agreement.order(:date, :id).to_a
    if agreements.empty?
      room = Inventory::ReadModels::Resource.where(resource_type: "conference_room", status: "available").order(:name).first
      return step("contracts", "contracts", "request_quote", "Request a quote for #{room.name}",
                  "Contracts opens the agreement; the room, hours and client details stay in Contracts' words.")
    end

    agreement = agreements.find { |candidate| %w[requested draft sent generated].include?(candidate.status) }
    return unless agreement

    case agreement.status
    when "requested"
      step("contracts", "contracts", "create_draft",
           "Price and create the draft for #{agreement.client_name}",
           "#{agreement.company}: Contracts publishes DraftAgreementCreated.",
           agreement_id: agreement.id)
    when "draft"
      step("contracts", "contracts", "send_draft", "Send the draft to the client",
           "Publishes DraftAgreementSent; Negotiations opens with Contracts' terms verbatim.",
           agreement_id: agreement.id)
    when "sent"
      step("contracts", "contracts", "generate", "Generate the agreement",
           sent_hint(agreement), agreement_id: agreement.id)
    when "generated"
      step("contracts", "contracts", "sign", "Sign the agreement",
           "AgreementSigned reserves the room and settles the billing terms.",
           agreement_id: agreement.id)
    end
  end

  def sent_hint(agreement)
    negotiation = Negotiations::ReadModels::Negotiation.find_by(agreement_id: agreement.id)
    return "DocuWare renders the document; the signed terms then reserve the room." unless negotiation&.open_proposal

    "Negotiations has a proposal on the table; accepting it changes the agreement before you generate."
  end

  def step(panel, context, command, title, hint, **args)
    Step.new(panel:, context:, command:, title:, hint:, args:)
  end
end
