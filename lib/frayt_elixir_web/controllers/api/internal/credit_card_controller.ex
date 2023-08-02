defmodule FraytElixirWeb.API.Internal.CreditCardController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixirWeb.ChangesetParams
  alias FraytElixir.Payments
  alias FraytElixir.Payments.CreditCard

  import FraytElixirWeb.SessionHelper, only: [authorize_shipper: 2]

  plug :authorize_shipper

  action_fallback FraytElixirWeb.FallbackController

  defparams(
    credit_card_params(%{
      stripe_token!: :string,
      stripe_card!: :string
    })
  )

  def create(%{assigns: %{current_shipper: shipper}} = conn, params) do
    with {:ok, attrs} <- credit_card_params(params) |> ChangesetParams.get_data(),
         {:ok, %CreditCard{} = credit_card} <-
           attrs
           |> Map.put(:shipper, shipper)
           |> Payments.create_credit_card() do
      conn
      |> put_status(:created)
      |> render("show.json", credit_card: credit_card)
    end
  end

  def show(%{assigns: %{current_shipper: shipper}} = conn, _) do
    {:ok, credit_card} = Payments.get_credit_card_for_shipper(shipper)
    render(conn, "show.json", credit_card: credit_card)
  end

  def delete(conn, %{"id" => id}) do
    credit_card = Payments.get_credit_card!(id)

    with {:ok, %CreditCard{}} <- Payments.delete_credit_card(credit_card) do
      send_resp(conn, :no_content, "")
    end
  end
end
