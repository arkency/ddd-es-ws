# frozen_string_literal: true

module Reservations
  # The process, in Reservations' own language. No aggregate: the commands read the catalog
  # (Inventory/Pricing projections), ask Availability for the only decision that needs
  # serialization, then move the reservation read model and publish facts.
  module Commands
    extend self

    NotBookable = Class.new(StandardError)
    NotAwaitingPayment = Class.new(StandardError)
    AmountMismatch = Class.new(StandardError)

    # --- client-facing --------------------------------------------------------

    # Desk pre-reservation -> offer presented for the whole opening hours of that day.
    # The offer takes a temporary hold; payment turns it into a full hold (see settle).
    def pre_reserve_desk(client:, resource_id:, date:)
      date = Date.iso8601(date.to_s)
      desk = ReadModels::Desk.find_by(resource_id: resource_id)
      raise NotBookable, "desk #{resource_id} is unknown or withdrawn" if desk.nil? || desk.withdrawn
      raise NotBookable, "desk #{resource_id} has no tariff yet" unless desk.rate_cents

      period = Integrations::AvailabilityConformist.opening_hours(resource_id: resource_id, date: date)
      raise NotBookable, "Availability knows no opening hours for #{desk.label}" unless period

      reservation_id = SecureRandom.uuid
      ActiveRecord::Base.transaction do
        Integrations::AvailabilityConformist.temporarily_block(period, reference: reservation_id)
        reservation = create_reservation!(
          id: reservation_id, resource_id: resource_id, resource_type: desk.resource_type, client: client,
          label: desk.label, date: date, from_hour: period.from_hour, to_hour: period.to_hour,
          amount_cents: desk.rate_cents,
        )
        publish(ReservationRequested.new(data: reservation_data(reservation)))
      end
      reservation_id
    end

    # --- called by ACLs, in Reservations' own language ------------------------

    # One Inventory event, two possible tables. The resource_type in the event decides.
    def register_resource(resource_id:, resource_type:, name:, zone: nil, capacity: nil)
      model = ReadModels::Catalog.model_for(resource_type)
      return unless model

      resource = model.find_or_initialize_by(resource_id: resource_id)
      resource.withdrawn = false if resource.new_record?
      resource.update!(name: name, **(resource_type == "desk" ? { zone: zone } : { capacity: capacity }))
    end

    def withdraw_resource(resource_id:)
      ReadModels::Catalog.withdraw(resource_id)
    end

    # Events are async, so the tariff can arrive before the resource itself. Tolerate both orders.
    def set_rate(resource_id:, resource_type:, rate_cents:, rate_unit:)
      model = ReadModels::Catalog.model_for(resource_type)
      return unless model

      model.find_or_initialize_by(resource_id: resource_id).update!(rate_cents: rate_cents, rate_unit: rate_unit)
    end

    # A signed agreement reserves the room for the agreed hours. The agreement is the decision,
    # so a room that is free is booked even outside its opening hours; only a clash rejects it.
    def request_conference_room(agreement_ref:, client:, resource_id:, date:, from_hour:, to_hour:, amount_cents:)
      reservation_id = Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "agreement:#{agreement_ref}")
      return reservation_id if ReadModels::Reservation.exists?(reservation_id) # redelivered event

      room = ReadModels::ConferenceRoom.find_by(resource_id: resource_id)
      period = Availability::Public::Period.new(resource_id: resource_id, date: date, from_hour: from_hour, to_hour: to_hour)
      booking = {
        id: reservation_id, resource_id: resource_id, resource_type: "conference_room", client: client,
        label: room&.label || resource_id, date: date, from_hour: from_hour, to_hour: to_hour,
        amount_cents: amount_cents, agreement_ref: agreement_ref,
      }

      ActiveRecord::Base.transaction do
        Integrations::AvailabilityConformist.block(period, reference: reservation_id)
        reservation = create_reservation!(**booking)
        publish(ReservationRequested.new(data: reservation_data(reservation)))
      rescue Availability::Public::NotAvailable => e
        reservation = create_reservation!(**booking.merge(status: "rejected: #{e.message}", amount_cents: 0))
        publish(ReservationRejected.new(data: reservation_data(reservation).merge(reason: e.message)))
      end
      reservation_id
    end

    # Payment received: the reservation is paid, so its temporary hold becomes a full one.
    def settle(reservation_id:, paid_cents:)
      ActiveRecord::Base.transaction do
        booking = ReadModels::Reservation.find(reservation_id)
        return if booking.status == "reserved" # redelivered payment event

        raise NotAwaitingPayment, "reservation #{reservation_id} is #{booking.status}" unless booking.status == "awaiting_payment"
        raise AmountMismatch, "paid #{paid_cents}, expected #{booking.amount_cents}" unless paid_cents == booking.amount_cents

        Integrations::AvailabilityConformist.block(
          Availability::Public::Period.new(resource_id: booking.resource_id, date: booking.date,
                                            from_hour: booking.from_hour, to_hour: booking.to_hour),
          reference: reservation_id,
        )
        booking.update!(status: "reserved")
        publish(Public::ReservationConfirmed.new(data: reservation_data(booking)))
      end
    end

    # Payment timed out: the offer expires and whatever it held on the resource is released.
    def expire(reservation_id:)
      ActiveRecord::Base.transaction do
        booking = ReadModels::Reservation.find(reservation_id)
        return if booking.status == "expired" # redelivered timeout

        raise NotAwaitingPayment, "reservation #{reservation_id} is #{booking.status}" unless booking.status == "awaiting_payment"

        Integrations::AvailabilityConformist.release(resource_id: booking.resource_id, reference: reservation_id)
        booking.update!(status: "expired")
        publish(ReservationExpired.new(data: { reservation_id: reservation_id }))
      end
    end

    private

    def create_reservation!(id:, resource_id:, resource_type:, client:, label:, date:, from_hour:, to_hour:,
                            amount_cents:, agreement_ref: nil, status: "awaiting_payment")
      ReadModels::Reservation.create!(
        id: id, resource_id: resource_id, resource_type: resource_type, client: client, label: label,
        date: date, from_hour: from_hour, to_hour: to_hour, amount_cents: amount_cents,
        agreement_ref: agreement_ref, status: status,
      )
    end

    def reservation_data(reservation)
      {
        reservation_id: reservation.id, resource_id: reservation.resource_id,
        resource_type: reservation.resource_type, client: reservation.client, label: reservation.label,
        date: reservation.date, from_hour: reservation.from_hour, to_hour: reservation.to_hour,
        amount_cents: reservation.amount_cents, agreement_ref: reservation.agreement_ref,
      }
    end

    def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "Reservations")
  end
end
