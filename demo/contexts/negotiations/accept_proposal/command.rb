# frozen_string_literal: true

module Negotiations
  module AcceptProposal
    # Downstream calling upstream's command API is allowed: the dependency still points
    # Negotiations -> Contracts. We ask Contracts to change the terms, then learn that *our
    # own* proposal was accepted only when Contracts' event comes back through ContractsConformist.
    Command = Data.define(:agreement_id)
  end
end
