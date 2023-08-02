defmodule FraytElixirWeb.ChangesetParams do
  @doc """
  Returns map of attrs, containing all valid keys provided in changeset params even when nil.
  """
  alias Ecto.Changeset
  def get_data(%Changeset{valid?: false} = changeset), do: {:error, changeset}

  def get_data(%Changeset{params: params, valid?: true} = changeset) do
    data = Params.data(changeset)

    {:ok, extract_data(data, params)}
  end

  defp extract_data(%_{} = data, %{} = params), do: extract_data(Map.from_struct(data), params)

  defp extract_data(%{} = data, %{} = params) do
    data
    |> Enum.reduce([], fn {key, value}, acc ->
      string_key = Atom.to_string(key)

      case params do
        %{^string_key => param_value} ->
          acc ++ [{key, extract_data(value, param_value)}]

        _ ->
          acc
      end
    end)
    |> Enum.into(%{})
  end

  defp extract_data(data, params) when is_list(data) and is_list(params) do
    Enum.zip(data, params)
    |> Enum.reduce([], fn {data, params}, acc ->
      acc ++ [extract_data(data, params)]
    end)
  end

  defp extract_data(data, _params), do: data
end
