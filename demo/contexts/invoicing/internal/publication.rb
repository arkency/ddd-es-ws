# frozen_string_literal: true

module Invoicing
  module Internal
    module Publication
      extend self

      def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "Invoicing")
    end
  end
end
