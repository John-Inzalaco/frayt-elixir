defmodule FraytElixirWeb.API.Internal.NpsScoreController do
  use FraytElixirWeb, :controller
  alias FraytElixir.Rating
  alias FraytElixirWeb.FallbackController
  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]
  action_fallback(FraytElixirWeb.FallbackController)

  plug(:authorize_driver)
  plug(:validate_driver_nps_score)

  def update(conn, params) do
    with {:ok, _} <-
           Rating.add_nps_feedback(conn.assigns.nps_score, %{
             feedback: Map.get(params, "feedback"),
             score: params["score"]
           }) do
      conn
      |> put_status(201)
      |> render("feedback.json", score: params["score"], feedback: Map.get(params, "feedback"))
    end
  end

  defp validate_driver_nps_score(
         %{
           params: %{"nps_score_id" => nps_score_id},
           assigns: %{current_driver: %{id: driver_id}}
         } = conn,
         _
       ) do
    case Rating.get_nps_score(nps_score_id) do
      %{user: %{driver: %{id: ^driver_id}}} = nps_score ->
        assign(conn, :nps_score, nps_score)

      _ ->
        FallbackController.call(conn, {:error, :not_found})
    end
  end
end
