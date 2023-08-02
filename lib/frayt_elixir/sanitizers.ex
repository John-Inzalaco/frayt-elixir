defmodule FraytElixir.Sanitizers do
  import Ecto.Changeset

  def strip_nondigits(changeset, field) do
    case fetch_field(changeset, field) do
      {:changes, incoming_field_value} when not is_nil(incoming_field_value) ->
        new_value = String.replace(incoming_field_value, ~r/\D+/, "")
        put_change(changeset, field, new_value)

      {:changes, nil} ->
        changeset

      {:data, _} ->
        changeset
    end
  end

  def convert_to_lowercase(changeset, field) do
    case fetch_field(changeset, field) do
      {:changes, incoming_field_value} when not is_nil(incoming_field_value) ->
        new_value = String.downcase(incoming_field_value)
        put_change(changeset, field, new_value)

      {:changes, nil} ->
        changeset

      {:data, _} ->
        changeset
    end
  end

  def trim_string(changeset, field) do
    case fetch_field(changeset, field) do
      {:changes, incoming_field_value} when not is_nil(incoming_field_value) ->
        new_value = String.trim(incoming_field_value)
        put_change(changeset, field, new_value)

      {:changes, nil} ->
        changeset

      {:data, _} ->
        changeset
    end
  end
end
