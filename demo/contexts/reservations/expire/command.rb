# frozen_string_literal: true

module Reservations
  module Expire
    # Payment timed out: the offer expires and whatever it held on the resource is released.
    Command = Data.define(:reservation_id)
  end
end
