defmodule FraytElixir.Type.HTML do
  use Ecto.Type

  def type, do: :string

  def cast(data) when is_binary(data), do: {:ok, HtmlSanitizeEx.basic_html(data)}

  def cast(_), do: :error

  def load(data) when is_binary(data), do: {:ok, data}

  def dump(data) when is_binary(data), do: {:ok, data}
  def dump(_), do: :error
end
