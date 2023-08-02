defmodule FraytElixir.Holistics do
  use Joken.Config
  alias FraytElixir.Holistics.HolisticsDashboard
  alias FraytElixir.Repo

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def sign_embed_token(secret_key, permissions \\ %{}) do
    expired_time = DateTime.to_unix(DateTime.utc_now()) + 12 * 60 * 60

    settings = %{
      "enable_export_data" => true
    }

    filters = %{}

    permissions =
      Map.merge(
        %{
          "row_based" => []
        },
        permissions
      )

    claims = %{
      "settings" => settings,
      "filters" => filters,
      "permissions" => permissions,
      "exp" => expired_time
    }

    signer = Joken.Signer.create("HS256", secret_key)
    generate_and_sign(claims, signer)
  end

  def get_dashboard_embed_url(%HolisticsDashboard{} = dashboard) do
    api_url = get_config(:api_url)

    with {:ok, token, _claims} <- sign_embed_token(dashboard.secret_key) do
      {:ok, "#{api_url}/embed/#{dashboard.embed_code}?_token=#{token}"}
    end
  end

  def get_dashboard(id) when is_binary(id), do: Repo.get(HolisticsDashboard, id)

  def change_dashboard(dashboard, attrs \\ %{}) do
    HolisticsDashboard.changeset(dashboard, attrs)
  end

  def upsert_dashboard(dashboard, attrs) do
    dashboard
    |> change_dashboard(attrs)
    |> Repo.insert_or_update()
  end

  def list_dashboards do
    HolisticsDashboard |> Repo.all()
  end
end
