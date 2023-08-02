defmodule FraytElixir.Test.FakeGeo do
  def geocode("1266 Norman Ave, Cincinnati OH 45231" = address),
    do: geocode_result(address)

  def geocode("641 Evangeline Rd, Cincinnati OH 45240" = address),
    do: geocode_result(address, 39.2821743197085, -84.51153768029151)

  def geocode("4533 Ruebel Place, Cincinnati, Ohio 45211"),
    do: geocode_result("4533 Ruebel Place")

  def geocode("4533 Ruebel Place , Cincinnati, Ohio 45211"),
    do: geocode_result("4533 Ruebel Place")

  def geocode("4533 Ruebel Place, Cincinnati, OH 45211"),
    do: geocode_result("4533 Ruebel Place")

  def geocode("708 Walnut Street, Cincinnati"),
    do: geocode_result("708 Walnut Street 500, Cincinnati, Ohio 45202")

  def geocode("4533 Ruebel Place , Cincinnati, OH 45211"),
    do: geocode_result("4533 Ruebel Place")

  def geocode("501 W National Rd, OH , USA, Englewood"), do: geocode_result("englewood")
  def geocode("501 W National Rd, OH , USA, Englewood,  45322"), do: geocode_result("englewood")

  def geocode("place_id:ChIJE0DHwm5LQIgRNhhS8Fl6AS8"),
    do: geocode_result("1266 Norman Ave, Cincinnati OH 45231")

  def geocode(""), do: geocode("garbage")
  def geocode(empty) when empty in [", ,  ", " , ,  "], do: geocode("garbage")
  def geocode("place_id:"), do: geocode("garbage")

  def geocode("garbage"),
    do: {:error, "ZERO_RESULTS"}

  def geocode("garbage, ,  "), do: geocode("garbage")

  def geocode(address), do: geocode_result(address)

  def geocode_result("1110 E Main St, Lancaster, OH 43130") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "1110",
               "short_name" => "1110",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "East Main Street",
               "short_name" => "E Main St",
               "types" => ["route"]
             },
             %{
               "long_name" => "Lancaster",
               "short_name" => "Lancaster",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Fairfield County",
               "short_name" => "Fairfield County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "43130",
               "short_name" => "43130",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "4055",
               "short_name" => "4055",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "1110 E Main St, Lancaster, OH 43130, USA",
           "geometry" => %{
             "location" => %{"lat" => 39.7132854, "lng" => -82.5805601},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 39.71463438029149,
                 "lng" => -82.57921111970849
               },
               "southwest" => %{
                 "lat" => 39.71193641970849,
                 "lng" => -82.58190908029151
               }
             }
           },
           "place_id" => "ChIJifRb1NyKR4gRhSvkrJPqf7c",
           "plus_code" => %{
             "compound_code" => "PC79+8Q Lancaster, OH, USA",
             "global_code" => "86FVPC79+8Q"
           },
           "types" => ["street_address"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("1320 River Valley Blvd Lancaster OH 43130") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "1320",
               "short_name" => "1266",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "River Valley Blvd",
               "short_name" => "Norman Ave",
               "types" => ["route"]
             },
             %{
               "long_name" => "Lancaster",
               "short_name" => "Cincinnati",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "43130",
               "short_name" => "43130",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "5523",
               "short_name" => "5523",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "1320 River Valley Blvd, Lancaster, OH 43130, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 39.2199586, "lng" => -84.53598480000001},
               "southwest" => %{"lat" => 39.2198316, "lng" => -84.5361121}
             },
             "location" => %{"lat" => 39.21988, "lng" => -84.5360534},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 39.2212440802915,
                 "lng" => -84.5346994697085
               },
               "southwest" => %{
                 "lat" => 39.2185461197085,
                 "lng" => -84.53739743029152
               }
             }
           },
           "place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("4533 Ruebel Place") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "4533",
               "short_name" => "4533",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "Ruebel Place",
               "short_name" => "Ruebel Pl",
               "types" => ["route"]
             },
             %{
               "long_name" => "Cincinnati",
               "short_name" => "Cincinnati",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Green Township",
               "short_name" => "Green Township",
               "types" => ["administrative_area_level_3", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "45211",
               "short_name" => "45211",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "4344",
               "short_name" => "4344",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "4533 Ruebel Pl, Cincinnati, OH 45211, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 39.1584976, "lng" => -84.6285764},
               "southwest" => %{"lat" => 39.158382, "lng" => -84.6286844}
             },
             "location" => %{"lat" => 39.1584446, "lng" => -84.62863829999999},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 39.1597887802915,
                 "lng" => -84.6272814197085
               },
               "southwest" => %{
                 "lat" => 39.1570908197085,
                 "lng" => -84.6299793802915
               }
             }
           },
           "place_id" => "ChIJi3Lh4_TKQYgRXWj661yNxus",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("1266 Norman Ave, Cincinnati OH 45231") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "1266",
               "short_name" => "1266",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "Norman Avenue",
               "short_name" => "Norman Ave",
               "types" => ["route"]
             },
             %{
               "long_name" => "Cincinnati",
               "short_name" => "Cincinnati",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "45231",
               "short_name" => "45231",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "5523",
               "short_name" => "5523",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "1266 Norman Ave, Cincinnati, OH 45231, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 39.2199586, "lng" => -84.53598480000001},
               "southwest" => %{"lat" => 39.2198316, "lng" => -84.5361121}
             },
             "location" => %{"lat" => 39.21988, "lng" => -84.5360534},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 39.2212440802915,
                 "lng" => -84.5346994697085
               },
               "southwest" => %{
                 "lat" => 39.2185461197085,
                 "lng" => -84.53739743029152
               }
             }
           },
           "place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("englewood") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "501",
               "short_name" => "501",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "West National Road",
               "short_name" => "W National Rd",
               "types" => ["route"]
             },
             %{
               "long_name" => "Englewood",
               "short_name" => "Englewood",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Montgomery County",
               "short_name" => "Montgomery County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "45322",
               "short_name" => "45322",
               "types" => ["postal_code"]
             }
           ],
           "formatted_address" => "501 W National Rd, Englewood, OH 45322, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 39.8776711, "lng" => -84.3117517},
               "southwest" => %{"lat" => 39.8767348, "lng" => -84.3127684}
             },
             "location" => %{"lat" => 39.8771627, "lng" => -84.3122908},
             "location_type" => "GEOMETRIC_CENTER",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 39.87855193029149,
                 "lng" => -84.3109110697085
               },
               "southwest" => %{
                 "lat" => 39.8758539697085,
                 "lng" => -84.3136090302915
               }
             }
           },
           "place_id" => "ChIJ-zcFsfiAP4gRLo8Gm3hvNrI",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("1808 Bennett Avenue, Chattanooga, TN 37404") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "1808",
               "short_name" => "1808",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "Bennett Avenue",
               "short_name" => "Bennett Ave",
               "types" => ["route"]
             },
             %{
               "long_name" => "Highland Park",
               "short_name" => "Highland Park",
               "types" => ["neighborhood", "political"]
             },
             %{
               "long_name" => "Chattanooga",
               "short_name" => "Chattanooga",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Tennessee",
               "short_name" => "TN",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "37404",
               "short_name" => "37404",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "4320",
               "short_name" => "4320",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "1808 Bennett Ave, Chattanooga, TN 37404, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 35.0294501, "lng" => -85.2790933},
               "southwest" => %{"lat" => 35.0292967, "lng" => -85.2792594}
             },
             "location" => %{"lat" => 35.0293578, "lng" => -85.2791788},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 35.0307223802915,
                 "lng" => -85.2778273697085
               },
               "southwest" => %{
                 "lat" => 35.0280244197085,
                 "lng" => -85.28052533029151
               }
             }
           },
           "place_id" => "ChIJjzfnjvtdYIgRJA7v9jeLMwI",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result("863 Dawsonville Hwy, Gainesville, GA 30501") do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{
               "long_name" => "863",
               "short_name" => "863",
               "types" => ["street_number"]
             },
             %{
               "long_name" => "Dawsonville Highway",
               "short_name" => "Dawsonville Hwy",
               "types" => ["route"]
             },
             %{
               "long_name" => "Highland Park",
               "short_name" => "Highland Park",
               "types" => ["neighborhood", "political"]
             },
             %{
               "long_name" => "Gainesville",
               "short_name" => "Gainesville",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hall County",
               "short_name" => "Hall County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Georgia",
               "short_name" => "GA",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{
               "long_name" => "30501",
               "short_name" => "30501",
               "types" => ["postal_code"]
             },
             %{
               "long_name" => "4320",
               "short_name" => "4320",
               "types" => ["postal_code_suffix"]
             }
           ],
           "formatted_address" => "1808 Bennett Ave, Chattanooga, TN 37404, USA",
           "geometry" => %{
             "bounds" => %{
               "northeast" => %{"lat" => 35.0294501, "lng" => -85.2790933},
               "southwest" => %{"lat" => 35.0292967, "lng" => -85.2792594}
             },
             "location" => %{"lat" => 35.0293578, "lng" => -85.2791788},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{
                 "lat" => 35.0307223802915,
                 "lng" => -85.2778273697085
               },
               "southwest" => %{
                 "lat" => 35.0280244197085,
                 "lng" => -85.28052533029151
               }
             }
           },
           "place_id" => "ChIJjzfnjvtdYIgRJA7v9jeLMwI",
           "types" => ["premise"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result({lat, lng}) do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{"long_name" => "500", "short_name" => "500", "types" => ["subpremise"]},
             %{"long_name" => "708", "short_name" => "708", "types" => ["street_number"]},
             %{"long_name" => "Walnut Street", "short_name" => "Walnut St", "types" => ["route"]},
             %{
               "long_name" => "Central Business District",
               "short_name" => "Central Business District",
               "types" => ["neighborhood", "political"]
             },
             %{
               "long_name" => "Cincinnati",
               "short_name" => "Cincinnati",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{"long_name" => "45202", "short_name" => "45202", "types" => ["postal_code"]}
           ],
           "formatted_address" => "708 Walnut St #500, Cincinnati, OH 45202, USA",
           "geometry" => %{
             "location" => %{"lat" => lat, "lng" => lng},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{"lat" => 39.1056687802915, "lng" => -84.51054221970848},
               "southwest" => %{"lat" => 39.1029708197085, "lng" => -84.51324018029149}
             }
           },
           "place_id" => "ChIJPxbiWFexQYgRgAdrmhWmg-U",
           "plus_code" => %{
             "compound_code" => "4F3Q+P6 Cincinnati, OH, United States",
             "global_code" => "86FQ4F3Q+P6"
           },
           "types" => ["street_address"]
         }
       ],
       "status" => "OK"
     }}
  end

  def geocode_result(address, lat \\ 39.1043198, lng \\ -84.5118912) do
    {:ok,
     %{
       "results" => [
         %{
           "address_components" => [
             %{"long_name" => "500", "short_name" => "500", "types" => ["subpremise"]},
             %{"long_name" => "708", "short_name" => "708", "types" => ["street_number"]},
             %{"long_name" => "Walnut Street", "short_name" => "Walnut St", "types" => ["route"]},
             %{
               "long_name" => "Central Business District",
               "short_name" => "Central Business District",
               "types" => ["neighborhood", "political"]
             },
             %{
               "long_name" => "Cincinnati",
               "short_name" => "Cincinnati",
               "types" => ["locality", "political"]
             },
             %{
               "long_name" => "Hamilton County",
               "short_name" => "Hamilton County",
               "types" => ["administrative_area_level_2", "political"]
             },
             %{
               "long_name" => "Ohio",
               "short_name" => "OH",
               "types" => ["administrative_area_level_1", "political"]
             },
             %{
               "long_name" => "United States",
               "short_name" => "US",
               "types" => ["country", "political"]
             },
             %{"long_name" => "45202", "short_name" => "45202", "types" => ["postal_code"]}
           ],
           "formatted_address" => address,
           "geometry" => %{
             "location" => %{"lat" => lat, "lng" => lng},
             "location_type" => "ROOFTOP",
             "viewport" => %{
               "northeast" => %{"lat" => 39.1056687802915, "lng" => -84.51054221970848},
               "southwest" => %{"lat" => 39.1029708197085, "lng" => -84.51324018029149}
             }
           },
           "place_id" => "ChIJPxbiWFexQYgRgAdrmhWmg-U",
           "plus_code" => %{
             "compound_code" => "4F3Q+P6 Cincinnati, OH, United States",
             "global_code" => "86FQ4F3Q+P6"
           },
           "types" => ["street_address"]
         }
       ],
       "status" => "OK"
     }}
  end

  def distance(_routes, _options \\ [])

  # Anchorage -> Wuhan
  def distance([{61.218056, -149.900284}, {30.592850, 114.305542}], _options) do
    {:ok,
     %{
       formatVersion: "0.0.12",
       error: %{
         description: "Engine error while executing route request: NO_ROUTE_FOUND"
       },
       detailedError: %{
         message: "Engine error while executing route request: NO_ROUTE_FOUND",
         code: "NO_ROUTE_FOUND"
       }
     }}
  end

  # gaslight point
  def distance([{39.1043198, -84.5118912}, _], _options) do
    tomtom_distance_result(5)
  end

  # 1320 River Valley Blvd Lancaster OH 43130 -> 1110 E Main St, Lancaster, OH 43130
  def distance(
        [{39.731200, -82.620850}, {39.713360, -82.580380}],
        _options
      ) do
    tomtom_distance_result(3.4)
  end

  # 1808 Bennett Ave, Chattanooga, TN 37404, USA
  def distance([{35.029380, -85.279190}, _], _options) do
    tomtom_distance_result(357)
  end

  # 1266 Norman Ave, Cincinnati, OH 45231, USA
  def distance([_, {39.219870, -84.536050}], _options) do
    tomtom_distance_result(9)
  end

  # 501 W National Rd, Englewood, OH 45322, USA
  def distance([_, {39.877810, -84.313490}], _options) do
    tomtom_distance_result(1.7)
  end

  # def distance("place_id:" <> _, "place_id:" <> _, _options) do
  #   tomtom_distance_result(21.4)
  # end

  def distance(routes, _options) when length(routes) > 2 do
    distance = 5 * 1609.34

    legs =
      0..(Enum.count(routes) - 2)
      |> Enum.map(fn _index ->
        # Compensating for returning distance in meters now so old tests don't break
        %{
          "summary" => %{
            "lengthInMeters" => distance
          }
        }
      end)

    total_distance = (Enum.count(routes) - 1) * distance

    {:ok,
     %{
       "routes" => [
         %{
           "legs" => legs,
           "summary" => %{
             "lengthInMeters" => total_distance,
             "travelTimeInSeconds" => 15 * 60
           }
         }
       ]
     }}
  end

  def distance([{_origin_lat, _origin_lng}, {_destination_lng, _destination_lat}], _options) do
    tomtom_distance_result(1.7)
  end

  def distance(_route, _options) do
    tomtom_distance_result(21.4)
  end

  defp tomtom_distance_result(distance) do
    {:ok,
     %{
       "routes" => [
         %{
           "legs" => [
             %{
               "summary" => %{
                 # Compensating for returning distance in meters now so old tests don't break
                 "lengthInMeters" => distance * 5280 / 3.281
               }
             }
           ],
           "summary" => %{
             "lengthInMeters" => distance * 5280 / 3.281,
             "travelTimeInSeconds" => distance * 90
           }
         }
       ]
     }}
  end
end
