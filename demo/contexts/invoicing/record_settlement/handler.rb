# frozen_string_literal: true

module Invoicing
  module RecordSettlement
    class Handler
      def call(command)
        ActiveRecord::Base.transaction do
          ReadModels::Settlement.find_or_initialize_by(order_ref: command.order_ref)
                                .update!(amount_cents: command.amount_cents)
          Internal::Publication.publish(
            SettlementRecorded.new(data: { order_ref: command.order_ref, amount_cents: command.amount_cents }),
          )
        end
      end
    end
  end
end
