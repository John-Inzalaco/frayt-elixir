defmodule FraytElixir.Document.State do
  @states [
    :pending_approval,
    :rejected,
    :approved
  ]

  use FraytElixir.Type.Enum, types: @states
end
