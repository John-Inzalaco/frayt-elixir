defmodule FraytElixir.Shipment.MatchFeeType do
  @types [
    :base_fee,
    :load_fee,
    :lift_gate_fee,
    :pallet_jack_fee,
    :pallet_fee,
    :toll_fees,
    :driver_tip,
    :route_surcharge,
    :item_surcharge,
    :holiday_fee,
    :return_charge,
    :handling_fee,
    :item_weight_fee,
    :wait_time_fee,
    :holding_fee,
    :priority_fee,
    :preferred_driver_fee
  ]

  use FraytElixir.Type.Enum,
    types: @types,
    names: [
      load_fee: "Load/Unload Fee"
    ]
end
