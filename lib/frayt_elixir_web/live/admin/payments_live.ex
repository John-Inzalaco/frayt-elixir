defmodule FraytElixirWeb.Admin.PaymentsLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/payments",
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :types, type: :atom, default: :all},
      %{key: :states, type: :atom, default: :all}
    ],
    model: :matches

  use FraytElixirWeb.ModalEvents
  alias FraytElixir.Payments
  alias FraytElixir.Shipment
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(socket, %{
         show_modal: false,
         transaction_response: nil
       })}
    end)
  end

  def handle_event(
        "retry_capture",
        %{"retry_form" => %{"match" => match_id}},
        socket
      ) do
    live_view_action(__MODULE__, "retry_capture", socket, fn ->
      match = Shipment.get_match(match_id)

      with %{status: "error"} <- Payments.get_latest_capture(match),
           {:ok, _} <- Payments.charge_match(match) do
        {:noreply,
         assign(
           socket,
           %{
             transaction_response: "We successfuly charged this match.",
             matches:
               socket.assigns.matches
               |> FraytElixir.Repo.preload(:payment_transactions, force: true)
           }
         )}
      else
        {:error, %{payment_provider_response: response}} ->
          %{"message" => msg} = Jason.decode!(response)

          {:noreply,
           assign(
             socket,
             :transaction_response,
             "We could not charge this match, reason: #{msg}"
           )}

        {:error, msg} ->
          {:noreply,
           assign(
             socket,
             :transaction_response,
             msg
           )}
      end
    end)
  end

  def handle_event("retry_transfer", %{"retry_form" => %{"match" => match_id}}, socket) do
    live_view_action(__MODULE__, "retry_transfer", socket, fn ->
      match = Shipment.get_match(match_id)

      with %{status: "error"} <- Payments.get_latest_transfer(match),
           {:ok, _} <- Payments.transfer_driver_pay(match) do
        {:noreply,
         assign(
           socket,
           %{
             transaction_response: "We successfuly transferred pay from this match.",
             matches:
               socket.assigns.matches
               |> FraytElixir.Repo.preload(:payment_transactions, force: true)
           }
         )}
      else
        {:error, %{payment_provider_response: response}} ->
          %{"status_reason" => reason} = Jason.decode!(response)

          {:noreply,
           assign(
             socket,
             :transaction_response,
             "We could not transfer pay from this match, reason: #{reason}"
           )}

        {:error, message} when is_binary(message) ->
          {:noreply,
           assign(
             socket,
             :transaction_response,
             "We could not transfer pay from this match, reason: #{message}"
           )}
      end
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.PaymentsView.render("index.html", assigns)
  end

  def list_records(socket, filters),
    do: {socket, Shipment.list_matches(filters)}
end
