# frozen_string_literal: true

require_relative "test_helper"

class FlowsTest < DemoTest
  DAY = "2026-11-20"

  def test_desk_reservation_end_to_end
    desk_id = given_priced_desk(price_cents: 4_500)

    reservation_id = Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)
    payment_id = Payments::Commands.request_payment(reference: reservation_id, payer: "Anna", amount_cents: 4_500)
    Payments::Commands.gateway_confirmed(payment_id: payment_id)
    deliver_async_events

    assert_equal "reserved", Reservations::ReadModels::Reservation.find(reservation_id).status
    assert_equal %w[Availability::OpeningHoursRecorded Availability::SlotTemporarilyBlocked Availability::SlotBlocked],
                 event_store.read.stream("Availability::Resource$#{desk_id}").map(&:event_type)

    invoice = Invoicing::ReadModels::Invoice.find_by!(order_ref: reservation_id)
    assert_equal ["sent", 4_500, "Anna"], [invoice.status, invoice.net_cents, invoice.buyer_name]
    assert invoice.settled?

    pass = FacilityAccess::ReadModels::Pass.find_by!(booking_ref: reservation_id)
    assert_equal ["Co-work floor", "code sent"], [pass.zone, pass.status]
    assert FacilityAccess::Commands.scan(code: pass.code, at: "#{DAY}T09:00")
    refute FacilityAccess::Commands.scan(code: pass.code, at: "2026-11-21T09:00")

    assert_equal %w[Anna Anna], OutboxMessage.order(:id).pluck(:recipient)
  end

  def test_desk_cannot_be_offered_twice_for_the_same_day
    desk_id = given_priced_desk(price_cents: 4_500)
    Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)

    assert_raises(Availability::Public::NotAvailable) do
      Reservations::Commands.pre_reserve_desk(client: "Bob", resource_id: desk_id, date: DAY)
    end
  end

  def test_payment_timeout_expires_offer_and_frees_the_desk
    desk_id = given_priced_desk(price_cents: 4_500)
    reservation_id = Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)
    payment_id = Payments::Commands.request_payment(reference: reservation_id, payer: "Anna", amount_cents: 4_500)

    Payments::Commands.gateway_timed_out(payment_id: payment_id)
    deliver_async_events

    assert_equal "expired", Reservations::ReadModels::Reservation.find(reservation_id).status
    assert Reservations::Commands.pre_reserve_desk(client: "Bob", resource_id: desk_id, date: DAY)
  end

  def test_withdrawn_desk_cannot_be_pre_reserved
    desk_id = given_priced_desk(price_cents: 4_500)
    Inventory::Commands.take_resource_out_of_service(resource_id: desk_id)
    deliver_async_events

    assert_raises(Reservations::NotBookable) do
      Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)
    end
    assert_nil Availability::Public.opening_hours(resource_id: desk_id, date: Date.iso8601(DAY))
  end

  def test_conference_room_from_negotiated_agreement_to_access
    room_id = Inventory::Commands.add_conference_room(name: "Orion", capacity: 12)
    deliver_async_events
    Inventory::Commands.add_availability_hours(resource_id: room_id, opens_at_hour: 8, closes_at_hour: 20)

    agreement_id = Contracts::Commands.request_quote(
      client_name: "Carol", company: "ACME Sp. z o.o.", tax_id: "PL5250001009", room_id: room_id,
      date: DAY, from_hour: 10, to_hour: 14,
    )
    Contracts::Commands.create_draft(agreement_id: agreement_id, price_cents: 100_000)
    Contracts::Commands.send_draft(agreement_id: agreement_id)
    deliver_async_events

    Negotiations::Commands.propose_price_change(agreement_id: agreement_id, price_cents: 80_000, proposed_by: "client")
    Negotiations::Commands.accept_proposal(agreement_id: agreement_id)
    deliver_async_events
    Negotiations::Commands.propose_hours_change(agreement_id: agreement_id, from_hour: 9, to_hour: 13, proposed_by: "client")
    Negotiations::Commands.reject_proposal(agreement_id: agreement_id)

    Contracts::Commands.apply_discount(agreement_id: agreement_id, percent: 10)
    Contracts::Commands.generate(agreement_id: agreement_id)
    Contracts::Commands.sign(agreement_id: agreement_id)
    deliver_async_events

    negotiation = Negotiations::ReadModels::Negotiation.find(agreement_id)
    assert_equal "concluded", negotiation.status
    assert_includes negotiation.history, "Price Change Accepted"
    assert_includes negotiation.history, "Availability Hours Change Rejected"
    assert_equal 72_000, negotiation.terms.fetch("total_cents")

    reservation = Reservations::ReadModels::Reservation.find_by!(agreement_ref: agreement_id)
    assert_equal ["awaiting_payment", 72_000, "conference_room"], [reservation.status, reservation.amount_cents, reservation.resource_type]

    payment_id = Payments::Commands.request_payment(reference: reservation.id, payer: "ACME Sp. z o.o.", amount_cents: 72_000)
    Payments::Commands.gateway_confirmed(payment_id: payment_id)
    deliver_async_events

    assert_equal "reserved", reservation.reload.status
    invoice = Invoicing::ReadModels::Invoice.find_by!(order_ref: reservation.id)
    assert_equal ["ACME Sp. z o.o.", "PL5250001009", 14], [invoice.buyer_name, invoice.tax_id, invoice.payment_terms_days]
    assert_equal "Orion (12 seats)", FacilityAccess::ReadModels::Pass.find_by!(booking_ref: reservation.id).zone
    assert IntegrationLog.exists?(integration: "Reservations::Integrations::AvailabilityConformist", message: "block (sync call)")
    assert_includes IntegrationLog.find_by!(integration: "Reservations::Integrations::ContractsAcl").read_models, "reservations_reservations"
  end

  def test_agreed_hours_outside_opening_hours_still_reserve_the_room
    room_id = Inventory::Commands.add_conference_room(name: "Orion", capacity: 12)
    deliver_async_events
    Inventory::Commands.add_availability_hours(resource_id: room_id, opens_at_hour: 8, closes_at_hour: 20)
    deliver_async_events

    agreed = sign_room_agreement(room_id: room_id, from_hour: 8, to_hour: 22)
    clash = sign_room_agreement(room_id: room_id, from_hour: 10, to_hour: 14)
    deliver_async_events

    reservation = Reservations::ReadModels::Reservation.find_by!(agreement_ref: agreed)
    assert_equal ["awaiting_payment", 100_000, 8, 22], [reservation.status, reservation.amount_cents, reservation.from_hour, reservation.to_hour]
    assert_equal "rejected: already taken", Reservations::ReadModels::Reservation.find_by!(agreement_ref: clash).status
  end

  def sign_room_agreement(room_id:, from_hour:, to_hour:)
    agreement_id = Contracts::Commands.request_quote(
      client_name: "Carol", company: "ACME Sp. z o.o.", tax_id: "PL5250001009", room_id: room_id,
      date: DAY, from_hour: from_hour, to_hour: to_hour,
    )
    Contracts::Commands.create_draft(agreement_id: agreement_id, price_cents: 100_000)
    Contracts::Commands.send_draft(agreement_id: agreement_id)
    Contracts::Commands.generate(agreement_id: agreement_id)
    Contracts::Commands.sign(agreement_id: agreement_id)
    agreement_id
  end

  def test_failing_downstream_does_not_undo_upstream
    desk_id = given_priced_desk(price_cents: 4_500)
    reservation_id = Reservations::Commands.pre_reserve_desk(client: "Anna", resource_id: desk_id, date: DAY)
    payment_id = Payments::Commands.request_payment(reference: reservation_id, payer: "Anna", amount_cents: 4_500)
    Payments::Commands.gateway_confirmed(payment_id: payment_id)

    Invoicing::Commands.define_singleton_method(:generate_invoice) { |**| raise "Invoicing is down" }
    begin
      assert_raises(RuntimeError) { deliver_async_events }
    ensure
      Invoicing::Commands.singleton_class.remove_method(:generate_invoice)
    end

    assert_equal "reserved", Reservations::ReadModels::Reservation.find(reservation_id).status
    assert_equal 1, event_store.read.of_type(Reservations::Public::ReservationConfirmed).to_a.size
    refute Invoicing::ReadModels::Invoice.exists?(order_ref: reservation_id)
  end

  private

  def given_priced_desk(price_cents:)
    desk_id = Inventory::Commands.add_desk(name: "D1", zone: "Window")
    deliver_async_events
    Pricing::Commands.assign_pricing(resource_id: desk_id, price_cents: price_cents)
    Inventory::Commands.add_availability_hours(resource_id: desk_id, opens_at_hour: 8, closes_at_hour: 18)
    deliver_async_events
    desk_id
  end
end
