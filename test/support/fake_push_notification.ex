defmodule FraytElixir.Test.FakePushNotification do
  def send("bad", _) do
    {:error,
     %{"errors" => ["Incorrect player_id format in include_player_ids (not a valid UUID): bad"]}}
  end

  def send(player_id, %{data: _data, title: _title, message: _message}) when is_list(player_id) do
    %OneSignal.Notification{
      id: "27d90540-e270-41a7-b9d2-ef3c26c1613d",
      recipients: 1
    }
  end

  def send(_device_id, %{data: _data, title: _title, message: _message}) do
    %OneSignal.Notification{
      id: "27d90540-e270-41a7-b9d2-ef3c26c1613d",
      recipients: 1
    }
  end
end
