defmodule FraytElixir.Drivers.Proficience do
  @types [
    :none,
    :beginner,
    :intermediate,
    :advanced
  ]

  use FraytElixir.Type.Enum,
    types: @types,
    names: [
      none: "None (Not Proficient)",
      advanced: "Advanced (Fluent)"
    ]
end
