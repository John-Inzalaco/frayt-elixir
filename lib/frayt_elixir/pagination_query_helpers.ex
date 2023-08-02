defmodule FraytElixir.PaginationQueryHelpers do
  import Ecto.Query, only: [from: 2, join: 5]
  alias FraytElixir.Shipment.{Address, Match}
  alias FraytElixir.SLAs.MatchSLA
  alias FraytElixir.Repo

  @split_name [:shipper_name, :driver_name]

  def list_record(query, filters, preload \\ [], select \\ & &1) do
    per_page = Map.get(filters, :per_page, 20)

    results =
      query
      |> order_by(
        Map.get(filters, :order_by, :inserted_at),
        Map.get(filters, :order, :desc)
      )
      |> paginate(Map.get(filters, :page, 0), Map.get(filters, :per_page, per_page))
      |> select.()
      |> Repo.all()
      |> Repo.preload(preload)

    pages =
      query
      |> page_count_without_select(per_page)

    {results, pages}
  end

  def remove_prefix(field, prefix) do
    to_string(field)
    |> String.trim_leading(prefix)
    |> String.to_atom()
  end

  def page_count(query, per_page) do
    from(m in query,
      select:
        fragment("cast(ceil(cast(? as numeric) / cast(? as numeric)) as int)", count(), ^per_page)
    )
    |> Repo.one()
  end

  def page_count_without_select(query, per_page) do
    ((query |> Repo.all() |> Enum.count()) / per_page) |> Float.ceil() |> round()
  end

  def paginate(query, page, per_page),
    do:
      from(m in query,
        offset: ^(page * per_page),
        limit: ^per_page
      )

  def api_paginate(query, %{order_by: field} = params) when is_nil(field) do
    params = Map.put(params, :order_by, :inserted_at)
    api_paginate(query, params)
  end

  def api_paginate(query, %{order_by: ""} = params) do
    params = Map.put(params, :order_by, :inserted_at)
    api_paginate(query, params)
  end

  def api_paginate(query, %{order_by: field} = params) when is_binary(field) do
    params = Map.put(params, :order_by, String.to_atom(field))
    api_paginate(query, params)
  end

  def api_paginate(query, %{
        offset: offset,
        limit: limit,
        order_by: field,
        descending: false
      }),
      do:
        from(m in query,
          offset: ^offset,
          limit: ^limit,
          order_by: ^[{:desc, field}]
        )

  def api_paginate(query, %{
        offset: offset,
        limit: limit,
        order_by: field,
        descending: true
      }),
      do:
        from(m in query,
          offset: ^offset,
          limit: ^limit,
          order_by: ^[{:desc, field}]
        )

  def order_by(query, field, order \\ :desc)

  def order_by(query, :sla, order) do
    order =
      case order do
        :desc -> :desc_nulls_last
        :asc -> :asc_nulls_last
      end

    from(m in query,
      left_join:
        csla in subquery(
          from(sla in MatchSLA,
            join: m0 in Match,
            on: m0.id == sla.match_id,
            where:
              (sla.type == :acceptance and m0.state == :assigning_driver) or
                (sla.type == :pickup and
                   m0.state in [:accepted, :en_route_to_pickup, :arrived_at_pickup]) or
                (sla.type == :delivery and m0.state == :picked_up),
            group_by: sla.match_id,
            select: %{
              match_id: sla.match_id,
              end_time: min(sla.end_time),
              start_time: max(sla.start_time)
            }
          )
        ),
      on: csla.match_id == m.id,
      order_by: [{^order, csla.end_time}, {^order, csla.start_time}, {^order, m.inserted_at}]
    )
  end

  def order_by(query, :service_level, order),
    do:
      from(m in query,
        order_by: [{^order, :service_level}, {^order, :pickup_at}, {^order, :dropoff_at}]
      )

  def order_by(query, :match_shipper_name, order),
    do:
      from(m in query,
        left_join: s in assoc(m, :shipper),
        order_by: [{^order, fragment("CONCAT(?, ' ', ?)", s.first_name, s.last_name)}]
      )

  def order_by(query, :network_operator_name, order),
    do:
      from(m in query,
        left_join: n in assoc(m, :network_operator),
        left_join: u in assoc(n, :user),
        order_by: [
          {^order, fragment("CASE WHEN ? IS NULL THEN ? ELSE ? END", n.name, u.email, n.name)}
        ]
      )

  def order_by(query, :match_driver_name, order),
    do:
      from(m in query,
        left_join: d in assoc(m, :driver),
        order_by: [{^order, fragment("CONCAT(?, ' ', ?)", d.first_name, d.last_name)}]
      )

  def order_by(query, :shipper_sales_rep, order),
    do:
      from(s in query,
        left_join: sr in assoc(s, :sales_rep),
        left_join: u in assoc(sr, :user),
        order_by: [
          {^order, fragment("CASE WHEN ? IS NULL THEN ? ELSE ? END", sr.name, u.email, sr.name)}
        ]
      )

  def order_by(query, :payment_status, order),
    do:
      from(p in query,
        order_by: [
          {^order,
           fragment("CASE WHEN ? IS NOT NULL THEN 'void' ELSE ? END", p.canceled_at, p.status)}
        ]
      )

  def order_by(query, :driver_home, order),
    do:
      from(m in query,
        join: a in Address,
        on: m.address_id == a.id,
        group_by: [a.state, a.city],
        order_by: [{^order, fragment("CONCAT(?, ', ', ?)", a.state, a.city)}]
      )

  def order_by(query, :driver_matches, order),
    do:
      from(d in query,
        left_join: dm in assoc(d, :metrics),
        order_by: [{^order, dm.completed_matches}]
      )

  def order_by(query, field, order) when field in @split_name,
    do:
      from(m in query,
        order_by: [{^order, fragment("CONCAT(?, ' ', ?)", m.first_name, m.last_name)}]
      )

  def order_by(query, :payment_payer_name, order),
    do:
      from(m in query,
        join: match in assoc(m, :match),
        join: shipper in assoc(match, :shipper),
        left_join: location in assoc(shipper, :location),
        left_join: company in assoc(location, :company),
        order_by: [
          {^order, is_nil(location.invoice_period) and is_nil(company.invoice_period)},
          {^order, fragment("CONCAT(?, ' ', ?)", shipper.first_name, shipper.last_name)}
        ]
      )

  def order_by(query, :coupon, order),
    do:
      from(m in query,
        left_join: match in assoc(m, :match),
        left_join: coupon in assoc(match, :coupon),
        order_by: [{^order, coupon.code}]
      )

  def order_by(query, :driver_applied_at, order) do
    from(m in query,
      left_join: st in FraytElixir.Drivers.DriverStateTransition,
      on: st.driver_id == m.id and st.from == :applying and st.to == :pending_approval,
      order_by: [{^order, st.inserted_at}, {^order, m.inserted_at}]
    )
  end

  def order_by(query, field, order),
    do:
      from(m in query,
        order_by: ^[{order, field}]
      )

  defmacro set_assoc(query, key, opts) do
    quote do
      q = unquote(query)
      k = unquote(key)
      [from: from_alias] = unquote(opts)

      if Map.has_key?(q.aliases, k) do
        q
      else
        join(q, :left, [{^from_alias, a}], a in assoc(a, ^k), as: unquote(key))
      end
    end
  end
end
