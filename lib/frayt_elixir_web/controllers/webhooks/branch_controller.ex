defmodule FraytElixirWeb.Webhook.BranchController do
  use FraytElixirWeb, :controller
  require Logger
  alias FraytElixirWeb.FallbackController
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver

  action_fallback FallbackController

  def handle_webhooks(conn, %{
        "event" => "ORGANIZATION_INITIALIZED_ACCOUNT_" <> state,
        "data" => data
      }) do
    with {:ok, %{"employee_id" => driver_id}} <- decrypt(data),
         %Driver{} = driver <- Drivers.get_driver(driver_id),
         {:ok, _driver} <- Drivers.update_driver_wallet(driver, get_wallet_state(state)) do
      conn
      |> render("success.json")
    else
      {:ok, _} -> {:error, :bad_request, "Missing employee_id"}
      nil -> {:error, :bad_request, "No Driver found with given employee_id"}
      error -> error
    end
  end

  def handle_webhooks(_conn, _params), do: {:error, :bad_request, "Invalid event id"}

  defp get_wallet_state("CLAIMED"), do: :ACTIVE
  defp get_wallet_state("CREATED"), do: :UNCLAIMED

  defp decrypt_cipher(value, key) do
    length = byte_size(value)

    with init_vector <- Kernel.binary_part(value, 0, 16),
         data <- Kernel.binary_part(value, 16, length - 16) do
      ExCrypto.decrypt(key, init_vector, data)
    end
  end

  defp decrypt(encrypted_value) do
    key = Application.get_env(:frayt_elixir, :branch_aes_key) |> Base.decode64!()

    with {:ok, encrypted_byte_value} <-
           Base.decode64(encrypted_value),
         {:ok, data} <-
           decrypt_cipher(encrypted_byte_value, key) do
      Jason.decode(data)
    else
      _ -> {:error, :forbidden}
    end
  end
end
