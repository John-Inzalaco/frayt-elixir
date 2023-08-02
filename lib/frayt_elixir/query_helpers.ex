defmodule FraytElixir.QueryHelpers do
  require Ecto.Query

  defmacro date_equals(field, date) do
    quote do
      fragment("?::date = ?::date", unquote(field), unquote(date))
    end
  end

  defmacro between?(field, min, max) do
    quote do
      unquote(field) >= unquote(min) and unquote(field) < unquote(max)
    end
  end
end
