defmodule FraytElixirWeb.Webhook.BringgView do
  use FraytElixirWeb, :view

  def render("success.json", %{merchant_uuid: merchant_uuid}) do
    %{
      success: true,
      merchant_uuid: merchant_uuid
    }
  end

  def render("success.json", %{match_id: match_id}) do
    %{
      success: true,
      delivery_id: match_id
    }
  end
end
