defmodule FraytElixir.Notifications.PushNotification do
  import OneSignal.Param
  require Logger

  def send(player_id, args) when is_binary(player_id), do: __MODULE__.send([player_id], args)

  def send(player_ids, %{data: data, title: title, message: message} = args)
      when is_list(player_ids) do
    OneSignal.new()
    |> put_heading(title)
    |> add_additional_data(data)
    |> put_message(message)
    |> put_player_ids(player_ids)
    |> notify()
  rescue
    error in HTTPoison.Error ->
      log_error(error, player_ids, args)

      {:error, error}

    error in Poison.SyntaxError ->
      log_error(error, player_ids, args)

      {:error, error}
  end

  defp log_error(error, player_id, args) do
    request = Map.put(args, :player_id, player_id)

    Logger.error(fn ->
      "OneSignal Response: Error: #{inspect(error)}; Request: #{inspect(request)}"
    end)
  end

  defp add_additional_data(param, %{} = data) do
    Enum.reduce(data, param, fn {k, v}, param -> put_data(param, k, v) end)
  end
end
