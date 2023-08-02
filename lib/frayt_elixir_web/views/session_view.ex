defmodule FraytElixirWeb.SessionView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.API.Internal.{DriverView, ShipperView}

  def render("authenticate_driver.json", %{token: token, driver: driver}) do
    %{
      response: %{
        token: token,
        driver: render_one(driver, DriverView, "driver.json")
      }
    }
  end

  def render("authenticate_shipper.json", %{token: token, shipper: shipper}) do
    %{
      response: %{
        token: token,
        shipper: render_one(shipper, ShipperView, "personal_shipper.json")
      }
    }
  end

  def render("authenticate.json", %{token: token}) do
    %{
      response: %{
        token: token
      }
    }
  end

  def render("error.json", %{message: message}) do
    %{
      error: %{
        message: message
      }
    }
  end

  def render("logout.json", %{message: message}) do
    %{
      message: message
    }
  end
end
