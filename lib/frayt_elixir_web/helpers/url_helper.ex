defmodule FraytElixirWeb.UrlHelper do
  alias FraytElixirWeb.Router.Helpers, as: Routes

  def get_api_matches_url(version),
    do: get_url(:index, version, &Routes.api_v2_match_path/3)

  def get_api_match_url(version, match),
    do: get_url(:show, version, &Routes.api_v2_match_path/4, match)

  def get_api_driver_url(version),
    do: get_url(:show, version, &Routes.api_v2_driver_path/3)

  def get_api_user_url(version, user),
    do: get_url(:show, version, &Routes.api_v2_user_path/4, user)

  defp get_url(action, version, callback, item \\ nil) do
    uri =
      FraytElixirWeb.Endpoint.url()
      |> URI.parse()

    version =
      case version do
        :v2 -> ""
        :V2x1 -> ".1"
      end

    case item do
      nil ->
        callback.(uri, action, version)

      _ ->
        callback.(uri, action, version, item)
    end
  end
end
