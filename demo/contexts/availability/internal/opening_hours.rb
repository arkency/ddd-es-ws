# frozen_string_literal: true

module Availability
  module Internal
    class OpeningHours < ActiveRecord::Base
      self.table_name = "availability_hours"
      self.primary_key = "resource_id"
    end
  end
end
