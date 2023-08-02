defmodule FraytElixir.Rating do
  alias FraytElixir.Repo
  alias FraytElixir.Rating.NpsScore

  def create_nps_score(user_id, user_type) do
    %NpsScore{}
    |> NpsScore.changeset(%{user_id: user_id, user_type: user_type})
    |> Repo.insert()
  end

  def add_nps_feedback(nps_score, %{score: score, feedback: feedback}) do
    nps_score
    |> NpsScore.feedback_changeset(%{feedback: feedback, score: score})
    |> Repo.update()
  end

  def get_nps_score(id) do
    NpsScore
    |> Repo.get(id)
    |> Repo.preload(user: [:shipper, :driver])
  end
end
