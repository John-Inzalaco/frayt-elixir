defmodule FraytElixirWeb.MatchPhoto do
  use Phoenix.LiveView
  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.Guards

  alias FraytElixir.{Repo, Shipment}
  alias Shipment.{Match, MatchStop}
  alias FraytElixirWeb.UploadHelper

  def mount(
        _params,
        %{
          "match" => match,
          "stop_id" => stop_id
        } = session,
        socket
      )
      when not is_empty(stop_id) do
    stop = match.match_stops |> Enum.find(&(&1.id == stop_id))

    {:ok, mount_socket(socket, session, stop)}
  end

  def mount(_params, %{"match" => match} = session, socket),
    do: {:ok, mount_socket(socket, session, match)}

  def handle_event(
        "save",
        _params,
        %{assigns: %{record: record, field: field, match: match, title: title}} = socket
      ) do
    {match, uploaded_file} =
      consume_uploaded_entries(socket, :match_photo, fn %{path: path},
                                                        %{client_name: file_name} ->
        upload_file(path, file_name, record, field)
      end)
      |> extract_assigns(match)

    send(socket.parent_pid, {:updated_match, match, "#{title} updated successfully"})

    {:noreply, assign(socket, %{photo_url: uploaded_file, match: match})}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :match_photo, ref)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("match_photo.html", assigns)
  end

  defp extract_assigns([{:ok, %Match{} = match, url}], _match), do: {match, url}

  defp extract_assigns([{:ok, %MatchStop{} = stop, url}], match) do
    {%Match{
       match
       | match_stops:
           Enum.map(match.match_stops, fn %MatchStop{id: stop_id} = orig_stop ->
             case stop do
               %MatchStop{id: ^stop_id} -> stop
               _ -> orig_stop
             end
           end)
     }, url}
  end

  defp upload_file(path, file_name, %Match{} = match, field) do
    with {:ok, file} <- UploadHelper.file_from_path(path, file_name, field),
         {:ok, match} <- Match.photo_changeset(match, %{field => file}) |> Repo.update() do
      {:ok, match, get_photo_url(match.id, Map.get(match, field))}
    end
  end

  defp upload_file(path, file_name, %MatchStop{} = stop, field) do
    with {:ok, file} <- UploadHelper.file_from_path(path, file_name, field),
         {:ok, stop} <- MatchStop.photo_changeset(stop, %{field => file}) |> Repo.update() do
      {:ok, stop, get_photo_url(stop.id, Map.get(stop, field))}
    end
  end

  defp get_caption(%MatchStop{signature_name: signature_name}, "signature_photo"),
    do: signature_name

  defp get_caption(_record, _name), do: nil

  defp mount_socket(socket, %{"field" => field} = session, record) when is_binary(field),
    do: mount_socket(socket, %{session | "field" => String.to_atom(field)}, record)

  defp mount_socket(socket, %{"field" => field, "match" => match}, record) do
    title = title_case(field)
    send(socket.parent_pid, {:set_title, title})

    socket
    |> assign(%{
      photo_url:
        get_photo_url(
          record.id,
          Map.get(record, field)
        ),
      photo_caption: get_caption(record, field),
      field: field,
      record: record,
      match: match,
      title: title
    })
    |> allow_upload(:match_photo,
      accept: ~w(.jpg .jpeg .png),
      max_entries: 1,
      max_file_size: 12_000_000
    )
  end
end
