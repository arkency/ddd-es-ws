# frozen_string_literal: true

require_relative "test_helper"

class ProcessGuideTest < DemoTest
  DAY = "2026-11-20"

  def test_guides_the_whole_happy_path
    assert_guide "inventory", "add_desk"
    desk_id = Inventory::Commands.add_desk(name: "D1", zone: "Window")

    assert_guide "inventory", "add_availability_hours"
    assert_equal desk_id, ProcessGuide.next_step.args[:resource_id]
    Inventory::Commands.add_availability_hours(resource_id: desk_id, opens_at_hour: 8, closes_at_hour: 18)
    deliver_async_events

    assert_guide "pricing", "assign_pricing"
    Pricing::Commands.assign_pricing(resource_id: desk_id, price_cents: 4_500)
    deliver_async_events

    assert_guide "reservations", "pre_reserve_desk"
    reservation_id = Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)

    assert_guide "reservations", "request_payment"
    payment_id = Payments::Commands.request_payment(reference: reservation_id, payer: "Anna", amount_cents: 4_500)

    assert_guide "payments", "gateway_confirmed"
    Payments::Commands.gateway_confirmed(payment_id: payment_id)
    deliver_async_events

    assert_guide "facility_access", "scan"
    pass = FacilityAccess::ReadModels::Pass.find_by!(booking_ref: reservation_id)
    assert FacilityAccess::Commands.scan(code: pass.code, at: "#{DAY}T09:00")

    assert_guide "inventory", "add_conference_room"
    room_id = Inventory::Commands.add_conference_room(name: "Orion", capacity: 12)

    assert_guide "inventory", "add_availability_hours"
    Inventory::Commands.add_availability_hours(resource_id: room_id, opens_at_hour: 8, closes_at_hour: 20)
    deliver_async_events

    assert_guide "contracts", "request_quote"
    agreement_id = Contracts::Commands.request_quote(
      client_name: "Carol", company: "ACME Sp. z o.o.", tax_id: "PL5250001009", room_id: room_id,
      date: DAY, from_hour: 10, to_hour: 14,
    )

    assert_guide "contracts", "create_draft"
    Contracts::Commands.create_draft(agreement_id: agreement_id, price_cents: 100_000)

    assert_guide "contracts", "send_draft"
    Contracts::Commands.send_draft(agreement_id: agreement_id)
    deliver_async_events

    assert_guide "contracts", "generate"
    Contracts::Commands.generate(agreement_id: agreement_id)

    assert_guide "contracts", "sign"
    Contracts::Commands.sign(agreement_id: agreement_id)
    deliver_async_events

    assert_guide "reservations", "request_payment"
    room_reservation = Reservations::ReadModels::Reservation.find_by!(agreement_ref: agreement_id)
    payment_id = Payments::Commands.request_payment(
      reference: room_reservation.id, payer: "ACME Sp. z o.o.", amount_cents: room_reservation.amount_cents,
    )

    assert_guide "payments", "gateway_confirmed"
    Payments::Commands.gateway_confirmed(payment_id: payment_id)
    deliver_async_events

    assert_guide "facility_access", "scan"
    room_pass = FacilityAccess::ReadModels::Pass.find_by!(booking_ref: room_reservation.id)
    assert FacilityAccess::Commands.scan(code: room_pass.code, at: "#{DAY}T10:30")
    deliver_async_events

    assert_nil ProcessGuide.next_step
  end

  def test_pending_payment_wins_over_an_unscanned_pass
    desk_id = Inventory::Commands.add_desk(name: "D1", zone: "Window")
    Inventory::Commands.add_availability_hours(resource_id: desk_id, opens_at_hour: 8, closes_at_hour: 18)
    deliver_async_events
    Pricing::Commands.assign_pricing(resource_id: desk_id, price_cents: 4_500)
    deliver_async_events

    first = Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)
    Payments::Commands.request_payment(reference: first, payer: "Anna", amount_cents: 4_500)
    Payments::Commands.gateway_confirmed(payment_id: Payments::ReadModels::Payment.find_by!(reference: first).id)
    deliver_async_events

    # The pass exists, but a second checkout is still pending: confirm that first.
    Reservations::Commands.pre_reserve_desk(client: "Bob", resource_id: desk_id, date: "2026-11-21")
    second = Reservations::ReadModels::Reservation.where(client: "Bob").first
    Payments::Commands.request_payment(reference: second.id, payer: "Bob", amount_cents: 4_500)

    assert_guide "payments", "gateway_confirmed"
  end

  private

  def assert_guide(panel, command)
    step = ProcessGuide.next_step
    refute_nil step, "expected #{panel}/#{command}, but the guide says the flow is complete"
    assert_equal [panel, command], [step.panel, step.command], "expected #{panel}/#{command}, got #{step.title.inspect}"
    refute_empty step.title
    refute_empty step.hint
  end
end
