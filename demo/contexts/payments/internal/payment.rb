# frozen_string_literal: true

module Payments
  module Internal
    class Payment
      include AggregateRoot

      AlreadyRequested = Class.new(StandardError)
      NotPending = Class.new(StandardError)

      def initialize(id)
        @id = id
        @status = :new
      end

      def request(reference:, payer:, amount_cents:)
        raise AlreadyRequested unless @status == :new

        apply PaymentRequested.new(data: { payment_id: @id, reference: reference, payer: payer, amount_cents: amount_cents })
      end

      def receive
        raise NotPending, "payment #{@id} is #{@status}" unless @status == :pending

        apply Public::PaymentReceived.new(data: { payment_id: @id, reference: @reference, payer: @payer, amount_cents: @amount_cents })
      end

      def time_out
        raise NotPending, "payment #{@id} is #{@status}" unless @status == :pending

        apply Public::PaymentTimedOut.new(data: { payment_id: @id, reference: @reference })
      end

      private

      on PaymentRequested do |event|
        @status = :pending
        @reference = event.data[:reference]
        @payer = event.data[:payer]
        @amount_cents = event.data[:amount_cents]
      end

      on Public::PaymentReceived do |_event|
        @status = :received
      end

      on Public::PaymentTimedOut do |_event|
        @status = :timed_out
      end
    end
  end
end
