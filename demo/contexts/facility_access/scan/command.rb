# frozen_string_literal: true

module FacilityAccess
  module Scan
    Command = Data.define(:code, :at) do
      def initialize(code:, at:) = super(code: code, at: Time.zone.parse(at.to_s))
    end
  end
end
