defmodule FraytElixirWeb.API.Internal.FeatureFlagController do
  use FraytElixirWeb, :controller

  import FraytElixirWeb.SessionHelper, only: [set_user: 2]

  plug(:set_user)

  def show(%{assigns: %{current_user: current_user}} = conn, %{"flag" => flag}) do
    {:ok, available_flags} = FunWithFlags.all_flag_names()

    case flag in Enum.map(available_flags, &Atom.to_string/1) do
      true ->
        enabled =
          flag
          |> String.to_atom()
          |> FunWithFlags.enabled?(for: current_user)

        render(conn, "show.json", %{enabled: enabled})

      false ->
        render(conn, "show.json", %{enabled: false})
    end
  end

  def show(conn, _params) do
    render(conn, "show.json", %{enabled: false})
  end
end
