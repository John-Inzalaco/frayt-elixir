defmodule FraytElixirWeb.NebulexSession do
  @moduledoc """
  Session store that uses Nebulex as a distributed storage.
  """

  @behaviour Plug.Session.Store
  alias FraytElixir.Cache
  alias Phoenix.{PubSub, LiveView}

  @default_table :phoenix_live_sessions
  @default_lifetime 14 * 24 * 60 * 60_000

  @max_tries 100

  def init(opts) do
    opts
    |> put_defaults()
  end

  def get(_conn, sid, opts) do
    table = Keyword.fetch!(opts, :table)

    with {data, expires_at} <-
           Cache.get({table, sid}),
         false <- DateTime.utc_now() |> DateTime.to_unix() > expires_at do
      {sid, put_meta(data, sid, opts)}
    else
      true ->
        Cache.delete({table, sid})
        {nil, %{}}

      nil ->
        {nil, %{}}
    end
  end

  def put(_conn, nil, data, opts) do
    put_new(data, opts)
  end

  def put(_conn, sid, data, opts) do
    table = Keyword.fetch!(opts, :table)
    Cache.put({table, sid}, {data, expires_at(opts)})
    broadcast_update(sid, data, opts)
    sid
  end

  def delete(_conn, sid, opts) do
    table = Keyword.fetch!(opts, :table)
    broadcast_update(sid, %{}, opts)
    Cache.delete({table, sid})
    :ok
  end

  defp put_new(data, opts, counter \\ 0)
       when counter < @max_tries do
    table = Keyword.fetch!(opts, :table)
    sid = Base.encode64(:crypto.strong_rand_bytes(96))

    if Cache.put_new({table, sid}, {data, expires_at(opts)}) do
      broadcast_update(sid, data, opts)
      sid
    else
      put_new(data, opts, counter + 1)
    end
  end

  defp put_in(sid, key, value, opts) do
    table = Keyword.fetch!(opts, :table)

    case Cache.get({table, sid}) do
      {data, _expires_at} ->
        updated_data = Map.put(data, key, value)

        Cache.put({table, sid}, {updated_data, expires_at(opts)})
        broadcast_update(sid, updated_data, opts)
        sid

      [] ->
        put(nil, sid, %{key => value}, opts)
    end
  end

  defp put_defaults(opts) do
    opts
    |> Keyword.put_new(:table, @default_table)
    |> Keyword.put_new(:lifetime, @default_lifetime)
  end

  defp put_meta(data, sid, opts) do
    data
    |> Map.put(:__sid__, sid)
    |> Map.put(:__opts__, opts)
  end

  defp expires_at(opts) do
    lifetime = Keyword.fetch!(opts, :lifetime)

    DateTime.utc_now()
    |> DateTime.add(lifetime, :millisecond)
    |> DateTime.to_unix()
  end

  defp broadcast_update(sid, data, opts) do
    pub_sub = Keyword.fetch!(opts, :pub_sub)
    channel = "live_session:#{sid}"
    PubSub.broadcast(pub_sub, channel, {:live_session_updated, put_meta(data, sid, opts)})
  end

  #
  # PhoenixLiveSession-specific functions
  #

  @spec maybe_subscribe(Phoenix.LiveView.Socket.t(), Plug.Session.Store.session()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_subscribe(socket, session) do
    if LiveView.connected?(socket) do
      sid = Map.fetch!(session, :__sid__)
      opts = Map.fetch!(session, :__opts__)
      pub_sub = Keyword.fetch!(opts, :pub_sub)
      channel = "live_session:#{sid}"
      PubSub.subscribe(pub_sub, channel)

      put_in(socket.private[:live_session], id: sid, opts: opts)
    else
      socket
    end
  end

  @spec put_session(Phoenix.LiveView.Socket.t(), String.t() | atom(), term()) ::
          Phoenix.LiveView.Socket.t()
  def put_session(%Phoenix.LiveView.Socket{} = socket, key, value) do
    sid = get_in(socket.private, [:live_session, :id])
    opts = get_in(socket.private, [:live_session, :opts])
    put_in(sid, to_string(key), value, opts)

    socket
  end

  @spec put_session(%{__sid__: String.t(), __opts__: list()}, String.t() | atom(), term()) :: %{}
  def put_session(%{__sid__: sid, __opts__: opts}, key, value) do
    put_in(sid, to_string(key), value, opts)

    get(nil, sid, opts)
  end
end
