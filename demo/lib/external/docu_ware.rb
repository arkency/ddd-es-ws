# frozen_string_literal: true

module External
  # Fake of DocuWare: turns agreed terms into a signed-ready document.
  module DocuWare
    def self.generate(agreement_id:)
      "DW-#{agreement_id.first(8).upcase}"
    end
  end
end
