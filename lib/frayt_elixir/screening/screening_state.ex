defmodule FraytElixir.Screenings.ScreeningState do
  @types [:pending, :charged, :submitted, :completed, :failed, :skipped]

  use FraytElixir.Type.Enum,
    types: @types
end
