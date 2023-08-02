defmodule FraytElixir.Shipment.MatchTags do
  @moduledoc """
  The MatchTag context.
  """

  import Ecto.Query, warn: false
  alias FraytElixir.Shipment.{MatchTag, Match}
  alias FraytElixir.Repo
  alias FraytElixir.Accounts
  alias FraytElixir.Notifications.Slack

  def create_tag(%Match{} = match, name) do
    attrs = %{
      match_id: match.id,
      name: name
    }

    %MatchTag{}
    |> MatchTag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List all MatchTags for a given match_id
  """
  def list_match_tags(match_id) do
    qry =
      from mt in MatchTag,
        where: mt.match_id == ^match_id

    Repo.all(qry)
  end

  def set_new_match_tag(%Match{} = match) do
    if Accounts.new_shipper?(match.shipper_id) do
      match = Repo.preload(match, [:shipper, :tags])

      Slack.send_shipper_message(match.shipper, message: "has placed their first Match!")

      with {:ok, match_tag} <- create_tag(match, :new) do
        tags = match.tags ++ [match_tag]
        {:ok, %{match | tags: tags}}
      end
    else
      {:ok, match}
    end
  end
end
