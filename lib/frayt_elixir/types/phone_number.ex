defmodule FraytElixir.Type.PhoneNumber do
  use Ecto.Type
  alias ExPhoneNumber.Model.PhoneNumber

  def type, do: :string

  def cast(phone_number) when is_binary(phone_number) do
    case sanitize_number(phone_number) do
      {:ok, phone_number} -> {:ok, phone_number}
      {:error, message} -> {:error, [message: message]}
      false -> {:error, [message: "Is not a valid phone number for this region"]}
    end
  end

  def cast(%PhoneNumber{} = phone_number), do: {:ok, phone_number}

  def cast(_), do: :error

  defp sanitize_number(phone_number) do
    case ExPhoneNumber.parse(phone_number, "") do
      {:ok, phone_number} ->
        {:ok, phone_number}

      error ->
        case phone_number |> String.replace(~r/[^\d]/, "") do
          number when byte_size(number) == 10 -> sanitize_number("+1" <> number)
          _ -> error
        end
    end
  end

  def load(data) when is_binary(data) do
    case ExPhoneNumber.parse(data, "") do
      {:ok, phone_number} -> {:ok, phone_number}
      {:error, _message} -> {:ok, nil}
    end
  end

  def dump(%PhoneNumber{} = phone_number), do: {:ok, ExPhoneNumber.format(phone_number, :e164)}
  # Temporary measure until all invalid phone numbers are resolved
  def dump(data) when is_binary(data), do: {:ok, data}
end
