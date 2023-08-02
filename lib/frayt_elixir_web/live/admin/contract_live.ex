defmodule FraytElixirWeb.Admin.ContractLive do
  use FraytElixirWeb, :live_view
  use FraytElixirWeb.AdminAlerts
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Contracts
  alias Contracts.Contract
  alias FraytElixir.Repo

  def mount(%{"id" => contract_id}, _session, socket) do
    {:ok, assign_contract(socket, contract_id)}
  end

  def handle_params(%{"id" => contract_id}, _uri, socket),
    do: {:noreply, assign_contract(socket, contract_id)}

  def handle_event("change_contract", %{"contract" => attrs}, socket) do
    changeset = get_changeset(socket, socket.assigns.editing, attrs)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("update_contract", %{"contract" => attrs}, socket) do
    changeset =
      get_changeset(socket, socket.assigns.editing, attrs)
      |> Map.put(:action, nil)

    socket =
      case Repo.insert_or_update(changeset) do
        {:ok, contract} ->
          contract = Repo.preload(contract, [:company, market_configs: :market])

          send_alert(
            :info,
            "Contract was successfully " <> if(changeset.data.id, do: "Updated", else: "Created")
          )

          socket
          |> assign(:contract, contract)
          |> push_patch(to: Routes.contract_path(socket, :index, contract.id), replace: true)

        {:error, %Ecto.Changeset{} = changeset} ->
          assign(socket, :changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("disable_contract", %{"disabled" => disabled}, socket) do
    case Contracts.update_contract(socket.assigns.contract, %{disabled: disabled}) do
      {:ok, contract} ->
        send_alert(
          :info,
          "Contract was successfully " <> if(disabled == "false", do: "Enabled", else: "Disabled")
        )

        {:noreply, socket |> assign(:contract, contract) |> toggle_edit(nil)}

      {:error, error} ->
        send_alert(:danger, DisplayFunctions.humanize_update_errors(error, "Contract"))
        {:noreply, socket}
    end
  end

  def handle_event("edit_contract", params, socket),
    do: {:noreply, toggle_edit(socket, Map.get(params, "edit"))}

  def handle_event("edit_slas", params, socket) do
    {:noreply, toggle_edit(socket, Map.get(params, "edit"))}
  end

  def handle_info({:update_changeset, callback, args}, socket) do
    changeset = apply(callback, [socket.assigns.changeset | args])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def render(assigns) do
    Phoenix.View.render(FraytElixirWeb.Admin.ContractsView, "contract.html", assigns)
  end

  defp toggle_edit(socket, nil), do: assign(socket, editing: nil, changeset: nil)

  defp toggle_edit(socket, form) do
    if user_has_role(socket.assigns.current_user, [:admin, :sales_rep]) do
      changeset = get_changeset(socket, form)

      assign(socket, editing: form, changeset: changeset)
    else
      toggle_edit(socket, nil)
    end
  end

  defp get_changeset(socket, form, attrs \\ %{}) do
    contract = socket.assigns.contract

    changeset =
      case form do
        "cancellation" ->
          contract
          |> Map.put(:enable_cancellation_code, not Enum.empty?(contract.cancellation_codes))
          |> Contracts.change_contract_cancellation(attrs)

        "contract" ->
          Contracts.change_contract(contract, attrs)

        "contract_sla" ->
          attrs = update_sla_attrs(socket.assigns.changeset, attrs)
          Contracts.change_contract_slas(contract, attrs)

        "delivery_rules" ->
          Contracts.change_contract_delivery_rules(contract, attrs)

        "edit_market_configs" ->
          Contracts.change_market_configs(contract, attrs)
      end

    Map.put(changeset, :action, :update)
  end

  defp update_sla_attrs(_changeset, %{"slas" => _} = attrs), do: attrs

  defp update_sla_attrs(nil, attrs), do: attrs

  defp update_sla_attrs(_changeset, attrs), do: Map.put(attrs, "slas", %{})

  defp assign_contract(socket, contract_id) do
    socket =
      case contract_id do
        "new" ->
          contract =
            get_contract(socket, contract_id, %Contract{
              company: nil,
              slas: [],
              cancellation_codes: []
            })

          socket
          |> assign(:contract, contract)
          |> toggle_edit("contract")

        _ ->
          contract = get_contract(socket, contract_id, Contracts.get_contract(contract_id))

          socket
          |> assign(:contract, contract)
          |> toggle_edit(nil)
      end

    if socket.assigns.contract do
      socket
    else
      redirect(socket, to: Routes.settings_path(socket, :index, :contracts))
    end
  end

  defp get_contract(
         %{assigns: %{contract: %Contract{id: id} = contract}},
         contract_id,
         _default
       )
       when id == contract_id,
       do: contract

  defp get_contract(_socket, _contract_id, default), do: default
end
