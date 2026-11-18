# frozen_string_literal: true

module Negotiations
  module Open
    # Called by ContractsConformist, with Contracts' terms as-is.
    Command = Data.define(:terms)
  end
end
