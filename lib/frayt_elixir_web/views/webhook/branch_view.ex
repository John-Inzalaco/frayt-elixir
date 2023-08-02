defmodule FraytElixirWeb.Webhook.BranchView do
  use FraytElixirWeb, :view

  def render("success.json", _) do
    %{
      data: %{
        message: "Successfully saved changes"
      }
    }
  end
end
