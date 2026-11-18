# frozen_string_literal: true

module FacilityAccess
  module Internal
    module Publication
      extend self

      def publish(event) = Rails.configuration.event_store.publish(event, stream_name: "FacilityAccess")
    end
  end
end
