# frozen_string_literal: true

module Negotiations
  module Abandon
    Command = Data.define(:agreement_id, :reason)
  end
end
