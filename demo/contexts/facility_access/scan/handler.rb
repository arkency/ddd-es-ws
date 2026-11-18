# frozen_string_literal: true

module FacilityAccess
  module Scan
    class Handler
      def call(command)
        pass = ReadModels::Pass.find_by(code: command.code.to_s.strip.upcase)
        reason =
          if pass.nil? then "unknown code"
          elsif pass.valid_on != command.at.to_date then "valid on #{pass.valid_on}, scanned on #{command.at.to_date}"
          elsif !(pass.from_hour...pass.to_hour).cover?(command.at.hour) then "valid #{pass.from_hour}:00-#{pass.to_hour}:00"
          end

        ActiveRecord::Base.transaction do
          Internal::Publication.publish(QrCodeScanned.new(data: { code: command.code, at: command.at }))
          ReadModels::Scan.create!(code: command.code, result: reason ? "rejected: #{reason}" : "accepted", scanned_at: command.at)
          if reason
            Internal::Publication.publish(QrCodeRejected.new(data: { code: command.code, reason: reason }))
            Internal::Publication.publish(CustomerServiceNotified.new(data: { code: command.code, reason: reason }))
          else
            Internal::Publication.publish(QrCodeAccepted.new(data: { code: command.code, pass_id: pass.id }))
          end
        end
        reason.nil?
      end
    end
  end
end
