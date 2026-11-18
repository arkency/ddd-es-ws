# frozen_string_literal: true

module FacilityAccess
  module ReadModels
    class Pass < ActiveRecord::Base
      self.table_name = "facility_access_passes"
    end

    class Scan < ActiveRecord::Base
      self.table_name = "facility_access_scans"
    end
  end
end
