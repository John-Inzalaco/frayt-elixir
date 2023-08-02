# Script for populating the development database. You can run it as:
#
#     mix run priv/repo/seeds.dev.exs

import FraytElixir.Factory

uname = System.user_home() |> Path.basename()
name = uname |> String.split(~r/[-_]/) |> Enum.join(" ") |> String.capitalize()

user_credentials = insert(:user, email: "user@frayt.com", password: "password@1")
driver_credentials = insert(:user, email: "driver@frayt.com", password: "password@1")
shipper_credentials = insert(:user, email: "shipper@frayt.com", password: "password@1")

driver = insert(:profiled_driver, first_name: name, last_name: "Driver", wallet_state: :UNCLAIMED, user: driver_credentials, can_load: true)

# driver that will need to update documents
needs_documents = insert(:profiled_driver,
  wallet_state: :UNCLAIMED,
  images: [],
  first_name: "Suspended",
  last_name: "Driver",
  user: build(:user, email: "documents@frayt.com", password: "password@1")
)

# driver whose application was rejected
rejected = insert(:profiled_driver,
  wallet_state: :UNCLAIMED,
  state: :rejected,
  first_name: "Rejected",
  last_name: "Driver",
  user: build(:user, email: "rejected@frayt.com", password: "password@1")
)

# driver who needs to set up wallet
missing_wallet_driver = insert(:profiled_driver, first_name: "MissingWallet", last_name: "Driver", wallet_state: :NOT_CREATED, user: build(:user, email: "payments@frayt.com", password: "password@1"), can_load: true)

# driver who needs to accept agreements
unaccepted_agreements_driver = insert(:profiled_driver, first_name: "Agreements", last_name: "Driver", wallet_state: :UNCLAIMED, user: build(:user, email: "agreements@frayt.com", password: "password@1"), can_load: true)

# driver who needs to set load/unload
load_unload_driver = insert(:profiled_driver, first_name: "LoadUnload", last_name: "Driver", wallet_state: :UNCLAIMED, user: build(:user, email: "loadunload@frayt.com", password: "password@1"), can_load: nil)

# driver who needs to update cargo capacity
cargo_capacity_driver = insert(:profiled_driver, first_name: name, last_name: "Driver", wallet_state: :UNCLAIMED, user: build(:user, email: "capacity@frayt.com", password: "password@1"), can_load: true, vehicles: [build(:vehicle, cargo_area_height: nil)])

insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 500, inserted_at: DateTime.utc_now(), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 1000, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 1), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 1500, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 2), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 2000, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 3), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 2500, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 4), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 3000, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 5), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 3500, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 6), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 4000, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 7), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 4500, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 15), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 5000, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 30), match: insert(:completed_match, driver: driver))
insert(:payment_transaction, transaction_type: :transfer, status: "succeeded", driver: driver, amount: 5500, inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * 45), match: insert(:completed_match, driver: driver))

%{company: %{locations: [location]} = company} =
  insert(:api_account,
    company:
      build(:company,
        name: "Frayt Technologies, Inc",
        locations: [
          build(:location,
            location: "Cincinnati, OH",
            store_number: "1",
            email: "support@frayt.com",
            company: nil
          )
        ]
      )
  )

shipper =
  insert(:shipper,
    user: shipper_credentials,
    first_name: name,
    last_name: "Shipper",
    location: location
  )

_admin_user = insert(:admin_user, name: name, role: :admin, user: user_credentials)

insert(:admin_user, role: :network_operator)
insert(:admin_user, role: :sales_rep)
insert(:admin_user, role: :member)
insert(:admin_user, role: :developer)

insert_list(2, :hidden_match,
  driver: driver,
  match: insert(:admin_canceled_match, shipper: shipper) |> with_transitions()
)

insert_list(10, :charged_match, shipper: shipper, driver: driver) |> with_transitions()
insert_list(3, :assigning_driver_match, shipper: shipper) |> with_transitions()
insert_list(4, :canceled_match, shipper: shipper) |> with_transitions()
insert_list(5, :charged_match, driver: driver) |> with_transitions()
insert(:accepted_match, shipper: shipper, driver: driver) |> with_transitions()

insert_list(15, :charged_match) |> with_transitions()
insert_list(5, :canceled_match) |> with_transitions()

tos = insert(:agreement_document, title: "Terms & Conditions", user_types: [:shipper, :driver])
privacy_policy = insert(:agreement_document, title: "Privacy Policy", user_types: [:driver])
driver_agreement = insert(:agreement_document, title: "Driver Agreement", user_types: [:driver])

insert(:user_agreement, agreed: false, user: unaccepted_agreements_driver.user, document: tos)
insert(:user_agreement, agreed: false, user: unaccepted_agreements_driver.user, document: privacy_policy)
insert(:user_agreement, agreed: false, user: unaccepted_agreements_driver.user, document: driver_agreement)

insert(:user_agreement, agreed: true, user: driver_credentials, document: tos)
insert(:user_agreement, agreed: true, user: driver_credentials, document: privacy_policy)
insert(:user_agreement, agreed: true, user: driver_credentials, document: driver_agreement)

insert(:user_agreement, agreed: true, user: rejected.user, document: tos)
insert(:user_agreement, agreed: true, user: rejected.user, document: privacy_policy)
insert(:user_agreement, agreed: true, user: rejected.user, document: driver_agreement)

insert(:user_agreement, agreed: true, user: needs_documents.user, document: tos)
insert(:user_agreement, agreed: true, user: needs_documents.user, document: privacy_policy)
insert(:user_agreement, agreed: true, user: needs_documents.user, document: driver_agreement)

insert(:user_agreement, agreed: true, user: missing_wallet_driver.user, document: tos)
insert(:user_agreement, agreed: true, user: missing_wallet_driver.user, document: privacy_policy)
insert(:user_agreement, agreed: true, user: missing_wallet_driver.user, document: driver_agreement)

insert(:user_agreement, agreed: true, user: load_unload_driver.user, document: tos)
insert(:user_agreement, agreed: true, user: load_unload_driver.user, document: privacy_policy)
insert(:user_agreement, agreed: true, user: load_unload_driver.user, document: driver_agreement)

insert(:contract,
  contract_key: "frayt",
  pricing_contract: :default,
  name: "Frayt",
  company: company
)

insert(:market,
  name: "Fort Worth, TX",
  markup: 1.05,
  has_box_trucks: true,
  calculate_tolls: true
)
|> with_zipcodes([
  "75022",
  "76001",
  "76002",
  "76005",
  "76006",
  "76010",
  "76011",
  "76012",
  "76013",
  "76014",
  "76015",
  "76016",
  "76017",
  "76018",
  "76019",
  "76020",
  "76021",
  "76022",
  "76028",
  "76034",
  "76036",
  "76039",
  "76040",
  "76051",
  "76052",
  "76053",
  "76054",
  "76060",
  "76063",
  "76092",
  "76094",
  "76096",
  "76098",
  "76101",
  "76102",
  "76103",
  "76104",
  "76105",
  "76106",
  "76107",
  "76108",
  "76109",
  "76110",
  "76111",
  "76112",
  "76114",
  "76115",
  "76116",
  "76117",
  "76118",
  "76119",
  "76120",
  "76122",
  "76123",
  "76126",
  "76127",
  "76129",
  "76130",
  "76131",
  "76132",
  "76133",
  "76134",
  "76135",
  "76137",
  "76140",
  "76147",
  "76148",
  "76155",
  "76161",
  "76164",
  "76166",
  "76177",
  "76179",
  "76180",
  "76181",
  "76182",
  "76192",
  "76196",
  "76197",
  "76199",
  "76244",
  "76248",
  "76262"
])

insert(:market,
  name: "Cincinnati, OH",
  markup: 1.1,
  has_box_trucks: false,
  calculate_tolls: true,
  currently_hiring: [:car, :cargo_van, :midsize, :box_truck]
)
|> with_zipcodes([
  "41005",
  "41011",
  "41012",
  "41014",
  "41015",
  "41016",
  "41017",
  "41018",
  "41019",
  "41022",
  "41051",
  "41071",
  "41072",
  "41075",
  "41076",
  "41091",
  "43950",
  "45069",
  "45202",
  "45203",
  "45204",
  "45205",
  "45206",
  "45207",
  "45208",
  "45211",
  "45212",
  "45213",
  "45214",
  "45215",
  "45216",
  "45217",
  "45219",
  "45220",
  "45223",
  "45224",
  "45225",
  "45226",
  "45227",
  "45229",
  "45230",
  "45231",
  "45232",
  "45233",
  "45236",
  "45237",
  "45238",
  "45239",
  "45241",
  "45243",
  "45248",
  "45251"
])

insert(:market,
  name: "Columbus, OH",
  markup: 1.5,
  has_box_trucks: false,
  calculate_tolls: true
)
|> with_zipcodes([
  "43085",
  "43201",
  "43202",
  "43203",
  "43204",
  "43205",
  "43206",
  "43207",
  "43209",
  "43210",
  "43211",
  "43212",
  "43213",
  "43214",
  "43215",
  "43217",
  "43219",
  "43220",
  "43221",
  "43222",
  "43223",
  "43224",
  "43227",
  "43228",
  "43229",
  "43230",
  "43231",
  "43232",
  "43235",
  "43240"
])

# creates and then disables the preferred_driver flag
FunWithFlags.disable(:preferred_driver)
FunWithFlags.enable(:preferred_driver, for_actor: shipper_credentials)
