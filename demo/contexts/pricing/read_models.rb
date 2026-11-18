# frozen_string_literal: true

module Pricing
  module ReadModels
    # Same shape as Inventory::ReadModels::Resource, plus a price.
    # That is what conforming looks like: one generic resource table, not one per feature.
    class Resource < ActiveRecord::Base
      self.table_name = "pricing_resources"
      self.primary_key = "resource_id"
    end
  end
end
