defmodule FraytElixirWeb.Admin.AgreementsLive do
  use Phoenix.LiveView

  use FraytElixirWeb.DataTable,
    base_url: "/admin/settings/agreements",
    default_filters: %{order_by: :updated_at},
    filters: [%{key: :query, type: :string, default: nil}],
    model: :agreements,
    handle_params: :root

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.AgreementDocument
  alias FraytElixir.Repo

  def mount(_params, %{"time_zone" => time_zone}, socket) do
    {:ok,
     assign(
       socket,
       %{
         time_zone: time_zone,
         changeset: nil,
         editing: nil
       }
     )}
  end

  def handle_event("cancel_edit", _session, socket) do
    {:noreply,
     assign(socket, %{
       changeset: nil,
       editing: nil
     })}
  end

  def handle_event(
        "delete_agreement:" <> agreement_id,
        _params,
        %{assigns: %{agreements: agreements}} = socket
      ) do
    with %AgreementDocument{} = agreement <- Enum.find(agreements, &(&1.id == agreement_id)),
         {:ok, _} <-
           Accounts.delete_agreement_document(agreement) do
      {:noreply,
       assign(socket,
         agreements: Enum.reject(agreements, &(&1.id == agreement_id)),
         editing: nil,
         changeset: nil
       )}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "edit_agreement:" <> id,
        _params,
        %{assigns: %{agreements: agreements}} = socket
      ) do
    agreement =
      case id do
        "new" -> %AgreementDocument{}
        _ -> Enum.find(agreements, &(&1.id == id))
      end

    socket =
      case agreement do
        %AgreementDocument{} ->
          socket
          |> assign_data_table(:show_more, id)
          |> assign(%{
            changeset: AgreementDocument.changeset(agreement, %{}),
            editing: id
          })

        _ ->
          assign(socket, %{changeset: nil, editing: nil})
      end

    {:noreply, socket}
  end

  def handle_event(
        "change_agreement",
        %{"agreement_document" => attrs},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    attrs = attrs |> Map.put("user_types", Map.get(attrs, "user_types", []))
    socket = assign(socket, :changeset, AgreementDocument.changeset(changeset.data, attrs))

    {:noreply, socket}
  end

  def handle_event(
        "update_agreement",
        _params,
        %{assigns: %{changeset: changeset, agreements: agreements, editing: editing}} = socket
      ) do
    socket =
      with {:ok, %{id: agreement_id} = agreement} <- Repo.insert_or_update(changeset),
           agreement <- Repo.preload(agreement, [:parent_document, :support_documents]) do
        agreements =
          case editing do
            "new" ->
              [agreement] ++ agreements

            _ ->
              Enum.map(agreements, fn a ->
                case a.id do
                  ^agreement_id -> agreement
                  _ -> a
                end
              end)
          end

        assign(socket, %{
          agreements: agreements,
          changeset: nil,
          editing: nil
        })
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          assign(socket, :changeset, changeset)
      end

    {:noreply, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.SettingsView.render("agreements.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Accounts.list_agreement_documents(filters)}
end
