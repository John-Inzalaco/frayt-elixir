defmodule FraytElixir.Cache do
  use Nebulex.Cache,
    otp_app: :frayt_elixir,
    adapter: Nebulex.Adapters.Multilevel

  defmodule L1 do
    use Nebulex.Cache,
      otp_app: :frayt_elixir,
      adapter: Nebulex.Adapters.Local
  end

  defmodule L2 do
    use Nebulex.Cache,
      otp_app: :frayt_elixir,
      adapter: Nebulex.Adapters.Partitioned
  end
end
