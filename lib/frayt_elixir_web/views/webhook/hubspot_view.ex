defmodule FraytElixirWeb.Webhook.HubspotView do
  use FraytElixirWeb, :view

  def render("success.json", _) do
    %{
      data: %{
        message: "Successfully saved data"
      }
    }
  end

  def render("error.json", %{error_count: error_count, total_count: total_count}) do
    %{
      data: %{
        message: "Failed to update #{error_count} of #{total_count} sales rep(s)"
      }
    }
  end
end
