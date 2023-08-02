defmodule FraytElixir.Notifications.Zapier do
  def get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  defp send_webhook(webhook, body) do
    base_url = get_config(:base_url)
    path = get_config(:webhooks, []) |> Keyword.get(webhook)

    cond do
      is_nil(base_url) ->
        {:error, "No base_url configured for Zapier"}

      is_nil(path) ->
        {:error, "No webhook configured for Zapier webhook '#{inspect(webhook)}'"}

      true ->
        url = base_url <> path

        HTTPoison.post(url, Jason.encode!(body))
    end
  end

  def send_match_status(match) do
    body = FraytElixirWeb.API.Internal.MatchView.render("match.json", match: match)

    send_webhook(:match_status, body)
  end
end
