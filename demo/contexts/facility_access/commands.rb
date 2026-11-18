# frozen_string_literal: true

module FacilityAccess
  module Commands
    extend self

    # Idempotent per booking.
    def grant_access(booking_ref:, holder:, zone:, valid_on:, from_hour:, to_hour:)
      return if ReadModels::Pass.exists?(booking_ref: booking_ref)

      ActiveRecord::Base.transaction do
        pass = ReadModels::Pass.create!(
          id: SecureRandom.uuid, booking_ref: booking_ref, holder: holder, zone: zone, valid_on: valid_on,
          from_hour: from_hour, to_hour: to_hour, code: SecureRandom.alphanumeric(8).upcase, status: "granted",
        )
        publish(AccessToCoworkGranted.new(data: pass.attributes.symbolize_keys.except(:id, :code, :status).merge(pass_id: pass.id)))

        External::MailingSystem.deliver(sender: "Facility Access", recipient: holder, subject: "Your QR code #{pass.code} for #{zone}")
        pass.update!(status: "code sent")
        publish(CodesSent.new(data: { pass_id: pass.id, recipient: holder }))
      end
    end

    def scan(code:, at:)
      at = Time.zone.parse(at.to_s)
      pass = ReadModels::Pass.find_by(code: code.to_s.strip.upcase)
      reason =
        if pass.nil? then "unknown code"
        elsif pass.valid_on != at.to_date then "valid on #{pass.valid_on}, scanned on #{at.to_date}"
        elsif !(pass.from_hour...pass.to_hour).cover?(at.hour) then "valid #{pass.from_hour}:00-#{pass.to_hour}:00"
        end

      ActiveRecord::Base.transaction do
        publish(QrCodeScanned.new(data: { code: code, at: at }))
        ReadModels::Scan.create!(code: code, result: reason ? "rejected: #{reason}" : "accepted", scanned_at: at)
        if reason
          publish(QrCodeRejected.new(data: { code: code, reason: reason }))
          publish(CustomerServiceNotified.new(data: { code: code, reason: reason }))
        else
          publish(QrCodeAccepted.new(data: { code: code, pass_id: pass.id }))
        end
      end
      reason.nil?
    end

    private

    def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "FacilityAccess")
  end
end
