defmodule FraytElixir.Accounts.DocumentState do
  @types [:draft, :published]

  use FraytElixir.Type.Enum,
    types: @types
end
