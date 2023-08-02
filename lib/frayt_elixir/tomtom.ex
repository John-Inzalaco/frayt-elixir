defmodule FraytElixir.TomTom do
  def get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)
end
