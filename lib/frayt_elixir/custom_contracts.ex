defmodule FraytElixir.CustomContracts do
  alias FraytElixir.Shipment.Match

  alias FraytElixir.Contracts.Contract

  alias FraytElixir.CustomContracts

  @contracts %{
    aafes: CustomContracts.AAFES,
    ashland_florist: CustomContracts.AshlandFlorist,
    atd: CustomContracts.Atd,
    atd_same_day: CustomContracts.ATDSameDay,
    axlehire: CustomContracts.AxleHire,
    axlehire_denton_to_dallas: CustomContracts.AxleHireDentonDallas,
    clmbr: CustomContracts.Clmbr,
    default: CustomContracts.Default,
    default_standard: CustomContracts.DefaultStandard,
    local_favorite: CustomContracts.LocalFavorite,
    lowes: CustomContracts.Lowes,
    menards: CustomContracts.Menards,
    menards_in_store: CustomContracts.MenardsInStore,
    nash_catering: CustomContracts.NashCatering,
    oberers: CustomContracts.Oberers,
    opl: CustomContracts.OPL,
    pepsi_snack_to_you: CustomContracts.PepsiSnacksToYou,
    pet_people: CustomContracts.PetPeople,
    pet_people_same_day: CustomContracts.PetPeopleSameDay,
    roti: CustomContracts.Roti,
    rug_doctor: CustomContracts.RugDoctor,
    share_bite: CustomContracts.ShareBite,
    sherwin: CustomContracts.SherwinStandard,
    sherwin_dash: CustomContracts.SherwinDash,
    sherwin_same_day: CustomContracts.SherwinSameDay,
    tbc: CustomContracts.TBC,
    tbc_same_day: CustomContracts.TBCSameDay,
    tile_shop_dash: CustomContracts.TileShopDash,
    tile_shop_same_day: CustomContracts.TileShopSameDay,
    tile_shop_standard: CustomContracts.TileShopStandard,
    tire_agent: CustomContracts.TireAgent,
    walmart: CustomContracts.Walmart,
    warehouse_anywhere: CustomContracts.WarehouseAnywhere,
    world_electric: CustomContracts.WorldElectric,
    xpress_run: FraytElixir.CustomContracts.XpressRun,
    zeitlins: CustomContracts.Zeitlins
  }

  @contract_names Map.keys(@contracts)

  use FraytElixir.Type.Enum,
    types: @contract_names

  def get_contracts, do: @contract_names

  def get_contract_module(%Contract{pricing_contract: name}) when name in @contract_names,
    do: @contracts[name]

  def get_contract_module(_), do: CustomContracts.Default

  def include_tolls?(match) do
    get_contract_module(match.contract).include_tolls?(match)
  end

  def calculate_pricing(match),
    do: get_contract_module(match.contract).calculate_pricing(match)

  def get_auto_configure_dropoff_at(contract),
    do: get_contract_module(contract).get_auto_configure_dropoff_at()

  def get_auto_dropoff_at_time(contract),
    do: get_contract_module(contract).get_auto_dropoff_at_time()

  def get_auto_cancel_on_driver_cancel_time_after_acceptance(%Match{contract: contract}),
    do: get_contract_module(contract).get_auto_cancel_on_driver_cancel_time_after_acceptance()

  def get_auto_cancel_on_driver_cancel(%Match{contract: contract}),
    do: get_contract_module(contract).get_auto_cancel_on_driver_cancel()

  def get_auto_cancel_time(%Match{contract: contract}),
    do: get_contract_module(contract).get_auto_cancel_time()
end
