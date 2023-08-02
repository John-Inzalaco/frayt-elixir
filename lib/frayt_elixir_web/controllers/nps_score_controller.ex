defmodule FraytElixirWeb.NpsScoreController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Rating
  alias FraytElixirWeb.FallbackController

  action_fallback(FallbackController)

  plug(:put_layout, "feedback.html")
  plug(:validate_score)
  plug(:validate_shipper_nps_score)

  def show(conn, params) do
    render(conn, "show.html",
      nps_score_id: params["nps_score_id"],
      score: String.to_integer(params["score"]),
      shipper_id: params["shipper_id"]
    )
  end

  def update(conn, params) do
    with {:ok, _} <-
           Rating.add_nps_feedback(conn.assigns.nps_score, %{
             feedback: Map.get(params, "feedback"),
             score: params["score"]
           }) do
      conn
      |> render("feedback.html",
        score: String.to_integer(params["score"])
      )
    end
  end

  defp validate_score(%{params: %{"score" => ""}} = conn, _) do
    conn
    |> put_status(:not_found)
    |> text("404 Not Found")
  end

  defp validate_score(%{params: %{"score" => score}} = conn, _) when is_binary(score), do: conn

  defp validate_score(conn, _) do
    conn
    |> put_status(:not_found)
    |> text("404 Not Found")
  end

  defp validate_shipper_nps_score(
         %{params: %{"nps_score_id" => nps_score_id, "shipper_id" => shipper_id}} = conn,
         _
       ) do
    with nps_score <- Rating.get_nps_score(nps_score_id),
         true <- nps_score.user.shipper.id == shipper_id do
      assign(conn, :nps_score, nps_score)
    end
  end
end
