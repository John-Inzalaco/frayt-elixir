defmodule FraytElixir.Integrations.Default do
  alias FraytElixirWeb.API.Internal.MatchView
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.API.V2x1.BatchView
  alias FraytElixir.Shipment.DeliveryBatch
  alias FraytElixir.Shipment.Match

  def put_auth_header(headers, %{auth_header: header, auth_token: token})
      when not is_nil(header) and not is_nil(token),
      do: headers ++ [{header, token}]

  def put_auth_header(headers, _config), do: headers

  def build_webhook_request(company, match, _) do
    body = build_body(match, company.webhook_config)
    [{company.webhook_url, body}]
  end

  defp build_body(%Match{} = match, %{api_version: :"2.1"}),
    do: MatchView.render("match.json", %{match: match})

  defp build_body(%Match{} = match, _config), do: DisplayFunctions.deprecated_match_status(match)

  defp build_body(%DeliveryBatch{} = batch, _config),
    do: BatchView.render("batch.json", %{batch: batch})
end
