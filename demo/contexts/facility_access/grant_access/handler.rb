# frozen_string_literal: true

module FacilityAccess
  module GrantAccess
    class Handler
      def call(command)
        return if ReadModels::Pass.exists?(booking_ref: command.booking_ref)

        ActiveRecord::Base.transaction do
          pass = ReadModels::Pass.create!(
            id: SecureRandom.uuid, booking_ref: command.booking_ref, holder: command.holder,
            zone: command.zone, valid_on: command.valid_on, from_hour: command.from_hour,
            to_hour: command.to_hour, code: SecureRandom.alphanumeric(8).upcase, status: "granted",
          )
          Internal::Publication.publish(
            AccessToCoworkGranted.new(
              data: pass.attributes.symbolize_keys.except(:id, :code, :status).merge(pass_id: pass.id),
            ),
          )

          External::MailingSystem.deliver(
            sender: "Facility Access", recipient: command.holder,
            subject: "Your QR code #{pass.code} for #{command.zone}",
          )
          pass.update!(status: "code sent")
          Internal::Publication.publish(CodesSent.new(data: { pass_id: pass.id, recipient: command.holder }))
        end
      end
    end
  end
end
