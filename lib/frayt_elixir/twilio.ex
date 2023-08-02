defmodule FraytElixir.Twilio do
  require Logger

  def create(data, opts \\ []) do
    ExTwilio.Message.create(data, opts)
  rescue
    error in HTTPoison.Error ->
      Logger.error(fn ->
        "Twilio Response: Error: #{inspect(error)}; Request: #{inspect(data)}"
      end)

      {:error, error}
  end
end
