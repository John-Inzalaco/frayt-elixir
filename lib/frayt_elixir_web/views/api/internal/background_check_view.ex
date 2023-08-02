defmodule FraytElixirWeb.API.Internal.BackgroundCheckView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.DriverView

  def render("payment_result.json", %{result: result, driver: driver}) do
    %{
      payment_intent_error: nil,
      requires_action: result.status === "requires_action",
      payment_intent_client_secret: result.client_secret,
      driver: render_one(driver, DriverView, "driver.json")
    }
  end

  def render("payment_result.json", %{error: error}) do
    %{
      payment_intent_error: error
    }
  end
end
