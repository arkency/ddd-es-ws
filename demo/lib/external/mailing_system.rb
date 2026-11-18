# frozen_string_literal: true

module External
  # Fake of the external "Mailing system" from the event storming board.
  module MailingSystem
    def self.deliver(sender:, recipient:, subject:)
      OutboxMessage.create!(sender: sender, recipient: recipient, subject: subject, created_at: Time.current)
    end
  end
end
