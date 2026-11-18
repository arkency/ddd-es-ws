# frozen_string_literal: true

module Reservations
  module Settle
    # Payment received: the reservation is paid, so its temporary hold becomes a full one.
    Command = Data.define(:reservation_id, :paid_cents)
  end
end
