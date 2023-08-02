defmodule FraytElixir.Markets do
  alias FraytElixir.Markets.{Market, MarketZipCode}
  alias FraytElixir.PaginationQueryHelpers
  alias FraytElixir.Repo

  import Ecto.Query

  def list_markets(filters \\ %{}) do
    query = Map.get(filters, :query)
    currently_hiring = Map.get(filters, :currently_hiring)

    Market
    |> Market.filter_by_query(query)
    |> Market.filter_by_hiring(currently_hiring)
    |> PaginationQueryHelpers.list_record(filters,
      zip_codes: from(z in MarketZipCode, order_by: z.zip)
    )
  end

  def delete_market(%Market{} = market) do
    Repo.delete(market)
  end

  def find_market_by_zip(nil), do: nil

  def find_market_by_zip(zip) do
    market = Repo.get_by(MarketZipCode, zip: zip) |> Repo.preload(:market)

    case market do
      %MarketZipCode{market: market} -> market
      _ -> nil
    end
  end

  def market_has_boxtrucks?(nil), do: false

  def market_has_boxtrucks?(market_id) when is_binary(market_id),
    do: Repo.get(Market, market_id) |> market_has_boxtrucks?()

  def market_has_boxtrucks?(%Market{has_box_trucks: true}), do: true
  def market_has_boxtrucks?(_market), do: false

  def list_currently_hiring_vehicles(market_id) do
    query =
      from m in Market,
        where: m.id == ^market_id,
        select: m.currently_hiring

    Repo.one(query)
  end
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Markets.Market do
  alias FraytElixir.{Repo, Markets}
  alias Markets.Market

  def display_record(m), do: "#{m.name}, #{m.region}"

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :name,
        order: :asc
      }
      |> Map.merge(filters)
      |> Markets.list_markets()

  def get_record(%{id: id}), do: Repo.get(Market, id)
end
