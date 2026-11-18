# frozen_string_literal: true

module Inventory
  # The context's public entry point, used by the UI and by Inventory's own integrations.
  # It holds no behaviour: one line per vertical slice, whose command and handler live in
  # <slice>/command.rb and <slice>/handler.rb. Ids are UUIDv7: time-ordered and index-friendly.
  module Commands
    extend self

    def add_desk(...) = AddDesk::Handler.new.call(AddDesk::Command.new(...))
    def add_conference_room(...) = AddConferenceRoom::Handler.new.call(AddConferenceRoom::Command.new(...))
    def add_photo(...) = AddPhoto::Handler.new.call(AddPhoto::Command.new(...))
    def add_availability_hours(...) = AddAvailabilityHours::Handler.new.call(AddAvailabilityHours::Command.new(...))
    def take_resource_out_of_service(...) = TakeResourceOutOfService::Handler.new.call(TakeResourceOutOfService::Command.new(...))
    def remove_resource(...) = RemoveResource::Handler.new.call(RemoveResource::Command.new(...))
  end
end
