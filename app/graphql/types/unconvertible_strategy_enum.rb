# frozen_string_literal: true

module Types
  class UnconvertibleStrategyEnum < Types::BaseEnum
    graphql_name "UnconvertibleStrategy"

    value "REFUSE", "Change nothing if any value cannot be converted", value: "refuse"
    value "CLEAR", "Clear values that cannot be converted (their ids are recorded on the version)", value: "clear"
  end
end
