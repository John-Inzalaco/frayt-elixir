defmodule FraytElixir.Test.FakeSlack do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_), do: {:ok, []}

  def send_message!(channel, message, options \\ %{})

  def send_message!(_channel, "this will timeout", %{compact: true}) do
    raise(HTTPoison.Error, reason: :timeout)
  end

  def send_message!(channel, message, %{compact: true}) do
    GenServer.cast(__MODULE__, {:send_message, {channel, message}})
  end

  def send_message!(_channel, message, %{thread_ts: thread_ts}) do
    %{
      "channel" => "C01AR5C1740",
      "message" => %{
        "bot_id" => "BFUQNBZJ6",
        "subtype" => "bot_message",
        "text" => message,
        "thread_ts" => thread_ts,
        "ts" => "1602127530.002700",
        "type" => "message",
        "username" => "FraytBot"
      },
      "ok" => true,
      "response_metadata" => %{"warnings" => ["superfluous_charset"]},
      "ts" => "1602127530.002700",
      "warning" => "superfluous_charset"
    }
  end

  def send_message!(channel, message, _options) do
    if message =~ ~r/start_thread/ do
      %{
        "channel" => "C01AR5C1740",
        "message" => %{
          "bot_id" => "BFUQNBZJ6",
          "subtype" => "bot_message",
          "text" => message,
          "ts" => "1602127530.001700",
          "type" => "message",
          "username" => "FraytBot"
        },
        "ok" => true,
        "response_metadata" => %{"warnings" => ["superfluous_charset"]},
        "ts" => "1602127530.001700",
        "warning" => "superfluous_charset"
      }
    else
      send_message!(channel, message, %{compact: true})
    end
  end

  def clear_messages do
    GenServer.cast(__MODULE__, :clear_messages)
  end

  def get_messages do
    GenServer.call(__MODULE__, :get_messages)
  end

  def get_messages(channel) do
    get_messages()
    |> Enum.filter(fn {c, _m} -> c == channel end)
  end

  def handle_cast({:send_message, message}, messages) do
    {:noreply, [message | messages]}
  end

  def handle_cast(:clear_messages, _) do
    {:noreply, []}
  end

  def handle_call(:get_messages, _from, messages) do
    {:reply, messages, messages}
  end
end
