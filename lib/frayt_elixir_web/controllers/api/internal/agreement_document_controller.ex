defmodule FraytElixirWeb.API.Internal.AgreementDocumentController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixir.Accounts

  import FraytElixirWeb.SessionHelper,
    only: [get_current_shipper: 1, get_current_driver: 1]

  action_fallback FraytElixirWeb.FallbackController

  def index(conn, %{"user_type" => user_type}) do
    user = get_user(conn, user_type)

    conn
    |> render("index.json", agreement_documents: Accounts.list_pending_agreements(user))
  end

  defparams(
    update_params(%{
      agreements!: [
        %{
          document_id!: :string,
          agreed!: :boolean
        }
      ]
    })
  )

  def create(conn, %{"user_type" => user_type} = params) do
    with user <- get_user(conn, user_type),
         %Ecto.Changeset{valid?: true} = changeset <- update_params(params),
         %{agreements: agreements} <- Params.to_map(changeset),
         {:ok, _} <-
           Accounts.accept_agreements(user, agreements) do
      conn
      |> render("index.json", agreement_documents: Accounts.list_pending_agreements(user))
    end
  end

  defp get_user(conn, type) when is_binary(type),
    do: get_user(conn, String.to_existing_atom(type))

  defp get_user(conn, :shipper), do: get_current_shipper(conn) || :shipper
  defp get_user(conn, :driver), do: get_current_driver(conn) || :driver
end
