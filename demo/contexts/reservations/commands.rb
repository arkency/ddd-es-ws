# frozen_string_literal: true

module Reservations
  # Public entry point: one line per vertical slice. The process itself lives in the slices;
  # there is no Reservation aggregate (see pre_reserve_desk/handler.rb and request_conference_room/handler.rb).
  module Commands
    extend self

    def pre_reserve_desk(...) = PreReserveDesk::Handler.new.call(PreReserveDesk::Command.new(...))
    def register_resource(...) = RegisterResource::Handler.new.call(RegisterResource::Command.new(...))
    def withdraw_resource(...) = WithdrawResource::Handler.new.call(WithdrawResource::Command.new(...))
    def set_rate(...) = SetRate::Handler.new.call(SetRate::Command.new(...))
    def request_conference_room(...) = RequestConferenceRoom::Handler.new.call(RequestConferenceRoom::Command.new(...))
    def settle(...) = Settle::Handler.new.call(Settle::Command.new(...))
    def expire(...) = Expire::Handler.new.call(Expire::Command.new(...))
  end
end
