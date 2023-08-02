defmodule FraytElixir.Convert do
  import FraytElixir.Guards
  def to_float(f, default \\ nil), do: convert_to(:float, f) || default
  def to_integer(i, default \\ nil), do: convert_to(:integer, i) || default
  def to_atom(a), do: convert_to(:atom, a)
  def to_string(s), do: convert_to(:string, s)
  def to_boolean(b), do: convert_to(:boolean, b)
  def to_list(l, type \\ nil), do: convert_to(:list, l, type)
  def value_or_nil(p), do: convert_to(:present_or_nil, p)

  defp convert_to(nil, param), do: param

  defp convert_to(type, param) when type not in [:list] and is_empty(param),
    do: nil

  defp convert_to(:present_or_nil, param), do: param

  defp convert_to(type, value) when type in [:float, :integer] and is_atom(value), do: nil

  defp convert_to(:integer, i) when is_integer(i), do: i
  defp convert_to(:integer, i) when is_float(i), do: floor(i)

  defp convert_to(:integer, i) do
    case Integer.parse(i) do
      :error -> nil
      {i, _} -> i
    end
  end

  defp convert_to(:float, f) when is_float(f), do: f
  defp convert_to(:float, f) when is_integer(f), do: f / 1

  defp convert_to(:float, f) do
    case Float.parse(f) do
      :error -> nil
      {f, _} -> f
    end
  end

  defp convert_to(:string, s) when is_binary(s), do: s
  defp convert_to(:string, s) when is_atom(s), do: Atom.to_string(s)
  defp convert_to(:string, s) when is_float(s), do: Float.to_string(s)
  defp convert_to(:string, s) when is_integer(s), do: Integer.to_string(s)

  defp convert_to(:atom, a) when is_atom(a), do: a

  defp convert_to(:atom, a) when is_binary(a) do
    String.to_existing_atom(a)
  rescue
    ArgumentError -> a
  end

  defp convert_to(:boolean, b) when is_boolean(b), do: b
  defp convert_to(:boolean, b) when is_binary(b), do: b == "true"

  defp convert_to(:list, param, type) when is_bitstring(param),
    do: param |> String.split(",") |> to_list(type)

  defp convert_to(:list, param, type) when is_list(param),
    do: param |> Enum.map(&convert_to(type, &1)) |> Enum.filter(& &1)

  defp convert_to(:list, _, _), do: []
end
