defmodule FraytElixir.Rating.NpsScore do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.{User, UserType}

  schema "nps_scores" do
    field(:user_type, UserType.Type)
    field(:score, :integer, default: nil)
    field(:feedback, :string)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(nps_score, attrs \\ %{}) do
    nps_score
    |> cast(attrs, [:user_id, :user_type, :score, :feedback])
    |> validate_inclusion(:score, 0..10)
  end

  def feedback_changeset(nps_score, attrs) do
    nps_score
    |> changeset(attrs)
    |> validate_required(:score)
    |> validate_feedback_required()
  end

  defp validate_feedback_required(changeset) do
    if Map.get(changeset.changes, :score) < 5 do
      validate_required(changeset, :feedback)
    else
      changeset
    end
  end
end
