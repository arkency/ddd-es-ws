# frozen_string_literal: true

module FacilityAccess
  # Public entry point: one line per vertical slice.
  module Commands
    extend self

    def grant_access(...) = GrantAccess::Handler.new.call(GrantAccess::Command.new(...))
    def scan(...) = Scan::Handler.new.call(Scan::Command.new(...))
  end
end
