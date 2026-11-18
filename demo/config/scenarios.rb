# frozen_string_literal: true

# Predefined scenarios for the Scenarios page. Pure presentation content: every step is one
# <Context>::Commands call in that context's own language (the runner adds no behaviour), plus
# what to wait for before the next step and what the run should end with.
#
# `args` is a Hash, or a lambda receiving the results of earlier steps keyed by `key:`.
# `wait_for` names the event types that must exist before the next step runs;
# `wait_deliveries` also waits until every subscribed context has handled them.
# `fault` arms ScenarioFault for the step (a downstream context fails on that delivery).
# `expect_error` marks a step that is supposed to fail with that error class (sync coupling).
module Scenarios
  Step = Data.define(:context, :command, :args, :key, :wait_for, :wait_deliveries, :fault, :expect_error, :note) do
    def resolved_args(results) = args.respond_to?(:call) ? args.call(results) : args
  end

  Scenario = Data.define(:key, :title, :kind, :blurb, :watch, :steps, :checks)

  def self.step(context:, command:, args: {}, key: nil, wait_for: [], wait_deliveries: true,
                fault: nil, expect_error: nil, note: nil)
    Step.new(context: context.to_s, command: command.to_s, args: args, key: key, wait_for: Array(wait_for),
             wait_deliveries: wait_deliveries, fault: fault, expect_error: expect_error, note: note)
  end

  def self.scenario(key:, title:, kind:, blurb:, watch: nil, steps:, checks: [])
    Scenario.new(key: key.to_s, title: title, kind: kind, blurb: blurb, watch: watch, steps: steps, checks: checks)
  end

  # ---- shared openings -------------------------------------------------------

  DESK_HOURS = step(
    context: "inventory", command: "add_availability_hours",
    args: ->(r) { { resource_id: r[:desk_id], opens_at_hour: 8, closes_at_hour: 18 } },
    wait_for: ["Inventory::Public::ResourceHoursAdded"],
  )

  def self.desk_priced
    [
      step(context: "inventory", command: "add_desk", args: { name: "D1", zone: "Window" },
           key: :desk_id, wait_for: ["Inventory::Public::ResourceAdded"]),
      DESK_HOURS,
      step(context: "pricing", command: "assign_pricing",
           args: ->(r) { { resource_id: r[:desk_id], price_cents: 4_500 } },
           wait_for: ["Pricing::Public::PricingAssigned"]),
    ]
  end

  PRE_RESERVE_ANNA = step(
    context: "reservations", command: "pre_reserve_desk",
    args: ->(r) { { client: "Anna", resource_id: r[:desk_id], date: "2026-11-20" } },
    key: :reservation_id, wait_for: ["Reservations::ReservationRequested"],
    note: "Calls Availability::Public synchronously: opening hours and the hold come back in the same request.",
  )

  # ---- scenarios -------------------------------------------------------------

  ALL = [
    scenario(
      key: "desk_end_to_end",
      title: "Desk, end to end",
      kind: "happy path",
      blurb: "Anna pre-reserves desk D1 for one day, pays, and gets an invoice and a door code.",
      watch: "PricingAssigned becomes a tariff in the PricingAcl; PaymentReceived fans out to three contexts at once.",
      steps: desk_priced + [
        PRE_RESERVE_ANNA,
        step(context: "payments", command: "request_payment",
             args: ->(r) { { reference: r[:reservation_id], payer: "Anna", amount_cents: 4_500 } },
             key: :payment_id, wait_for: ["Payments::PaymentRequested"]),
        step(context: "payments", command: "gateway_confirmed",
             args: ->(r) { { payment_id: r[:payment_id] } },
             wait_for: ["Payments::Public::PaymentReceived", "Reservations::Public::ReservationConfirmed"]),
        step(context: "facility_access", command: "scan",
             args: ->(r) { { code: FacilityAccess::ReadModels::Pass.find_by!(booking_ref: r[:reservation_id]).code,
                              at: "2026-11-20T09:30" } },
             wait_for: ["FacilityAccess::QrCodeAccepted"],
             note: "The pass is valid on 2026-11-20 only; scanning another day is rejected."),
      ],
      checks: [
        ["Reservation is reserved", -> { Reservations::ReadModels::Reservation.last&.status == "reserved" }],
        ["Invoice sent, 45.00 PLN, settled", lambda {
          invoice = Invoicing::ReadModels::Invoice.last
          invoice && invoice.status == "sent" && invoice.net_cents == 4_500 && invoice.settled?
        }],
        ["Pass code sent to Anna", -> { FacilityAccess::ReadModels::Pass.last&.status == "code sent" }],
        ["Two mails: invoice and code", -> { OutboxMessage.count == 2 }],
      ],
    ),

    scenario(
      key: "room_agreement",
      title: "Room through a negotiated agreement",
      kind: "happy path",
      blurb: "Carol's company negotiates Orion, gets a discount, signs, pays, and the invoice uses the company's billing terms.",
      watch: "Negotiations is a Conformist: it calls Contracts and learns its own proposal was accepted only from Contracts' event.",
      steps: [
        step(context: "inventory", command: "add_conference_room", args: { name: "Orion", capacity: 12 },
             key: :room_id, wait_for: ["Inventory::Public::ResourceAdded"]),
        step(context: "inventory", command: "add_availability_hours",
             args: ->(r) { { resource_id: r[:room_id], opens_at_hour: 8, closes_at_hour: 20 } },
             wait_for: ["Inventory::Public::ResourceHoursAdded"]),
        step(context: "contracts", command: "request_quote",
             args: ->(r) { { client_name: "Carol", company: "ACME Sp. z o.o.", tax_id: "PL5250001009",
                              room_id: r[:room_id], date: "2026-11-20", from_hour: 10, to_hour: 14 } },
             key: :agreement_id, wait_for: ["Contracts::QuoteRequested"]),
        step(context: "contracts", command: "create_draft",
             args: ->(r) { { agreement_id: r[:agreement_id], price_cents: 100_000 } },
             wait_for: ["Contracts::DraftAgreementCreated"]),
        step(context: "contracts", command: "send_draft",
             args: ->(r) { { agreement_id: r[:agreement_id] } },
             wait_for: ["Contracts::Public::DraftAgreementSent"],
             note: "Negotiations opens only now, with Contracts' terms verbatim."),
        step(context: "negotiations", command: "propose_price_change",
             args: ->(r) { { agreement_id: r[:agreement_id], price_cents: 80_000, proposed_by: "client" } },
             wait_for: ["Negotiations::PriceChangeProposed"]),
        step(context: "negotiations", command: "accept_proposal",
             args: ->(r) { { agreement_id: r[:agreement_id] } },
             wait_for: ["Contracts::Public::AgreementTermsChanged"],
             note: "Round trip: Negotiations asks Contracts, then waits for Contracts' event to come back."),
        step(context: "contracts", command: "apply_discount",
             args: ->(r) { { agreement_id: r[:agreement_id], percent: 10 } },
             wait_for: ["Contracts::Public::DiscountApplied"]),
        step(context: "contracts", command: "generate",
             args: ->(r) { { agreement_id: r[:agreement_id] } },
             wait_for: ["Contracts::AgreementGenerated"]),
        step(context: "contracts", command: "sign",
             args: ->(r) { { agreement_id: r[:agreement_id] } },
             wait_for: ["Contracts::Public::AgreementSigned", "Reservations::ReservationRequested"]),
        step(context: "payments", command: "request_payment",
             args: ->(r) {
               reservation = Reservations::ReadModels::Reservation.find_by!(agreement_ref: r[:agreement_id])
               { reference: reservation.id, payer: "ACME Sp. z o.o.", amount_cents: reservation.amount_cents }
             },
             key: :payment_id, wait_for: ["Payments::PaymentRequested"]),
        step(context: "payments", command: "gateway_confirmed",
             args: ->(r) { { payment_id: r[:payment_id] } },
             wait_for: ["Payments::Public::PaymentReceived", "Reservations::Public::ReservationConfirmed"]),
        step(context: "facility_access", command: "scan",
             args: ->(r) {
               reservation = Reservations::ReadModels::Reservation.find_by!(agreement_ref: r[:agreement_id])
               { code: FacilityAccess::ReadModels::Pass.find_by!(booking_ref: reservation.id).code, at: "2026-11-20T12:00" }
             },
             wait_for: ["FacilityAccess::QrCodeAccepted"]),
      ],
      checks: [
        ["Negotiation concluded", -> { Negotiations::ReadModels::Negotiation.last&.status == "concluded" }],
        ["Reservation reserved for ACME", -> { Reservations::ReadModels::Reservation.last&.status == "reserved" }],
        ["Invoice uses the contract's billing terms", lambda {
          invoice = Invoicing::ReadModels::Invoice.last
          invoice && invoice.buyer_name == "ACME Sp. z o.o." && invoice.tax_id == "PL5250001009" &&
            invoice.payment_terms_days == 14 && invoice.net_cents == 72_000
        }],
        ["Pass zone is the room", -> { FacilityAccess::ReadModels::Pass.last&.zone == "Orion (12 seats)" }],
      ],
    ),

    scenario(
      key: "payment_timeout",
      title: "Payment times out",
      kind: "mechanics",
      blurb: "Anna's offer expires, the temporary hold is released, and Bob can take the same desk.",
      watch: "Payments stays generic: it publishes PaymentTimedOut for an opaque reference. Reservations decides what expiry means.",
      steps: desk_priced + [
        PRE_RESERVE_ANNA,
        step(context: "payments", command: "request_payment",
             args: ->(r) { { reference: r[:reservation_id], payer: "Anna", amount_cents: 4_500 } },
             key: :payment_id, wait_for: ["Payments::PaymentRequested"]),
        step(context: "payments", command: "gateway_timed_out",
             args: ->(r) { { payment_id: r[:payment_id] } },
             wait_for: ["Payments::Public::PaymentTimedOut", "Reservations::ReservationExpired"]),
        step(context: "reservations", command: "pre_reserve_desk",
             args: ->(r) { { client: "Bob", resource_id: r[:desk_id], date: "2026-11-20" } },
             key: :bob_reservation_id, wait_for: ["Reservations::ReservationRequested"],
             note: "The same desk and day succeed: the expired offer no longer holds the slot."),
      ],
      checks: [
        ["Anna's reservation is expired", -> { Reservations::ReadModels::Reservation.find_by(client: "Anna")&.status == "expired" }],
        ["Bob's reservation is awaiting payment", -> { Reservations::ReadModels::Reservation.find_by(client: "Bob")&.status == "awaiting_payment" }],
        ["No invoice was issued", -> { Invoicing::ReadModels::Invoice.count.zero? }],
      ],
    ),

    scenario(
      key: "failing_downstream",
      title: "A failing downstream",
      kind: "mechanics",
      blurb: "Invoicing is down when the reservation is confirmed. The reservation and the ReservationConfirmed event survive.",
      watch: "The Invoicing edge stays in transit in the feed: the upstream transaction already committed.",
      steps: desk_priced + [
        PRE_RESERVE_ANNA,
        step(context: "payments", command: "request_payment",
             args: ->(r) { { reference: r[:reservation_id], payer: "Anna", amount_cents: 4_500 } },
             key: :payment_id, wait_for: ["Payments::PaymentRequested"]),
        step(context: "payments", command: "gateway_confirmed",
             args: ->(r) { { payment_id: r[:payment_id] } },
             fault: "Invoicing::Integrations::ReservationsAcl",
             wait_for: ["Payments::Public::PaymentReceived", "Reservations::Public::ReservationConfirmed"],
             wait_deliveries: false,
             note: "Invoicing fails on ReservationConfirmed. Nothing upstream is rolled back."),
        step(context: "reservations", command: "pre_reserve_desk",
             args: ->(r) { { client: "Bob", resource_id: r[:desk_id], date: "2026-11-21" } },
             wait_for: ["Reservations::ReservationRequested"],
             note: "Reservations is not wedged by the failed edge; a different day still books."),
      ],
      checks: [
        ["Reservation is reserved", -> { Reservations::ReadModels::Reservation.find_by(client: "Anna")&.status == "reserved" }],
        ["ReservationConfirmed was published once", -> { Rails.configuration.event_store.read.of_type([Reservations::Public::ReservationConfirmed]).to_a.size == 1 }],
        ["No invoice exists", -> { Invoicing::ReadModels::Invoice.count.zero? }],
        ["The Invoicing delivery is still in transit", lambda {
          IntegrationLog.where(integration: "Invoicing::Integrations::ReservationsAcl", handled_at: nil).exists?
        }],
      ],
    ),

    scenario(
      key: "sync_coupling",
      title: "Sync is coupled in time",
      kind: "mechanics",
      blurb: "Two clients pre-reserve the same desk for the same day. The second pre-reservation fails inside Reservations' transaction.",
      watch: "Availability is called synchronously: no event, no delay, and its NotAvailable error propagates into the caller. No aggregate on the Reservations side is needed for that.",
      steps: desk_priced + [
        PRE_RESERVE_ANNA,
        step(context: "reservations", command: "pre_reserve_desk",
             args: ->(r) { { client: "Bob", resource_id: r[:desk_id], date: "2026-11-20" } },
             expect_error: "Availability::Public::NotAvailable",
             wait_for: [], wait_deliveries: false,
             note: "Expected failure: the slot is already held for Anna."),
      ],
      checks: [
        ["Exactly one reservation exists", -> { Reservations::ReadModels::Reservation.count == 1 }],
        ["Only Anna holds the desk", -> { Reservations::ReadModels::Reservation.last&.client == "Anna" }],
      ],
    ),
  ].freeze

  def self.find(key)
    ALL.find { |scenario| scenario.key == key.to_s } || ALL.first
  end
end
