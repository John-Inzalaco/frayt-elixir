defmodule FraytElixirWeb.API.Internal.CreditCardView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.CreditCardView

  def render("index.json", %{credit_cards: credit_cards}) do
    %{data: render_many(credit_cards, CreditCardView, "credit_card.json")}
  end

  def render("show.json", %{credit_card: credit_card}) do
    %{response: render_one(credit_card, CreditCardView, "credit_card.json")}
  end

  def render("credit_card.json", %{credit_card: credit_card}) do
    %{credit_card: credit_card.last4}
  end
end
