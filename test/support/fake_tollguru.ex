defmodule FraytElixir.Test.FakeTollGuru do
  def call_api(:post, "/here", %{from: %{address: "invalid_address"}}),
    do:
      {:error, 400,
       %{
         "status" => "ERROR",
         "requestId" => "bad76f74-5feb-4ec6-947e-fd43f355a803",
         "message" => "Internal server error",
         "error" => "Point not found",
         "code" => "INPUT_ERROR"
       }}

  def call_api(:post, "/here", _body),
    do:
      {:ok,
       %{
         "meta" => %{
           "client" => "api",
           "customerId" => "cus_whatever",
           "source" => "HERE",
           "tx" => 6,
           "type" => "general",
           "userId" => "test@example.com"
         },
         "routes" => [
           %{
             "costs" => %{
               "cash" => nil,
               "creditCard" => nil,
               "fuel" => 1.31,
               "licensePlate" => nil,
               "prepaidCard" => 18.3,
               "tag" => 18.3
             },
             "directions" => [
               %{
                 "distance" => 40,
                 "duration" => 14,
                 "html_instructions" =>
                   "Head toward <span class=\"toward_street\">Broad Ave</span> on <span class=\"street\">Summit Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">131 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8580996, "longitude" => -73.9899897}
               },
               %{
                 "distance" => 430,
                 "duration" => 63,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Broad Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.8583152, "longitude" => -73.9903665}
               },
               %{
                 "distance" => 806,
                 "duration" => 126,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Fort Lee Rd</span> <span class=\"number\">(CR-12)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.5 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.861727, "longitude" => -73.9879203}
               },
               %{
                 "distance" => 211,
                 "duration" => 24,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> and take ramp onto <span class=\"next-street\">Bergen Blvd</span> <span class=\"number\">(US-1/US-9/US-46)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.1 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.8577681, "longitude" => -73.9801848}
               },
               %{
                 "distance" => 2316,
                 "duration" => 169,
                 "html_instructions" =>
                   "Take <span class=\"direction\">left</span> ramp onto <span class=\"number\">I-95 N</span> <span class=\"next-street\">(New Jersey Tpke N)</span> toward <span class=\"sign\"><span lang=\"en\">G Washington Bridge</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">1.4 mi</span>.</span>",
                 "maneuver" => "bearLeft",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8583903, "longitude" => -73.9778781}
               },
               %{
                 "distance" => 2009,
                 "duration" => 138,
                 "html_instructions" =>
                   "Continue on <span class=\"number\">I-95</span> <span class=\"next-street\">(George Washington Bridge)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.2 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "adminDivisionChange",
                     "text" => "Entering <span class=\"admin_division\">New York</span>",
                     "type" => "info"
                   },
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8515882, "longitude" => -73.9526117}
               },
               %{
                 "distance" => 7367,
                 "duration" => 390,
                 "html_instructions" =>
                   "Keep <span class=\"direction\">right</span> onto <span class=\"number\">I-95</span> <span class=\"next-street\">(Cross Bronx Expy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">4.6 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.8458376, "longitude" => -73.9301991}
               },
               %{
                 "distance" => 5308,
                 "duration" => 327,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">6A</span> toward <span class=\"sign\"><span lang=\"en\">Whitestone Br</span></span> onto <span class=\"number\">I-678 S</span> <span class=\"next-street\">(Hutchinson River Pkwy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8291221, "longitude" => -73.8475227}
               },
               %{
                 "distance" => 439,
                 "duration" => 35,
                 "html_instructions" =>
                   "Take <span class=\"direction\">left</span> exit <span class=\"exit\">16</span> toward <span class=\"sign\"><span lang=\"en\">Cross Is Pkwy South</span></span> onto <span class=\"next-street\">Cross Island Pkwy S</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "bearLeft",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.7905841, "longitude" => -73.8233721}
               },
               %{
                 "distance" => 544,
                 "duration" => 86,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">35</span> toward <span class=\"sign\"><span lang=\"en\">14 Ave</span>/<span lang=\"en\">Francis Lewis Blvd</span></span> onto <span class=\"next-street\">Cross Island Pkwy</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7890391, "longitude" => -73.8190806}
               },
               %{
                 "distance" => 321,
                 "duration" => 58,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">150th St</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7869899, "longitude" => -73.813405}
               },
               %{
                 "distance" => 185,
                 "duration" => 31,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">17th Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.1 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7841253, "longitude" => -73.8138127}
               },
               %{
                 "distance" => 79,
                 "duration" => 15,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Murray St</span>. <span class=\"distance-description\">Go for <span class=\"length\">259 ft</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7839644, "longitude" => -73.8116348}
               },
               %{
                 "distance" => 22,
                 "duration" => 3,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">17th Rd</span>. <span class=\"distance-description\">Go for <span class=\"length\">72 ft</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7832456, "longitude" => -73.8117206}
               },
               %{
                 "distance" => 0,
                 "duration" => 0,
                 "html_instructions" =>
                   "Arrive at <span class=\"street\">17th Rd</span>. Your destination is on the right.",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "previousIntersection",
                     "text" => "The last intersection is <span class=\"street\">17th Rd</span>",
                     "type" => "info"
                   },
                   %{
                     "code" => "nextIntersection",
                     "text" =>
                       "If you reach <span class=\"next-street\">150th St</span>, youâ€™ve gone too far",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.7832664, "longitude" => -73.8119872}
               }
             ],
             "polyline" =>
               "cbkxFldrbMk@jAuCkBmBgA}HkFgBiAzA}Cz@oBrBsDhA{BBi@PyADaBPcCZ_BXcATo@Xi@|@eAt@u@dBuBl@eAd@m@{AuEW}@Eo@AgCCg@@mAF_BPiBX_Bx@oCjBcErB}CpC}E^u@rDcG\\{@b@wA\\wAX{Ab@}Cn@aGX{EN_DPaCXoBNuAFmADiIz@qG~G}l@xEya@lA_Kl@cGZsAFg@VaCtEc^xAeGfBsFpA{Dd@yA~D_LT}ADsDb@cD~@uFRgAX_Cv@mFTgDJuCAiEMeD[{KM}FKcJC]GiEEcBEqJBaKJaJV_MHqGJiGvA{X|@wNbAiQT_Dj@gKXcD\\aCTiA~AoErDmI`EwIv@eBb@kAlCcGfFuKxAeDhAaDfBeHz@qFNsARoCHyBL}Gd@{PHiBd@mGPcBViBxBeLd@kBdB_JfEwS~@}EzEgVlAmGfDaPtByKbAuEdAoElAgDf@q@`@u@rAgCv@gBNc@TcAZkBHoA@{BG}BSgEy@iLMuB@kAF}@h@_D`@_Ad@u@n@o@^Wd@Ov@QtIsAnBOnBEfO?hLVdGTxELfGFlIBhAEr@It@K`AUbBg@lAe@rAs@nZwPvJoFll@i\\zZ{P|Aw@|Ak@fC]t@EjCIfAYVMd@_@`@g@^o@Pc@ZaBFaAEeERoDf@{Bf@iAjCuEZq@p@aC|@kCj@qBPkBZoHr@D`CVvF\\lCR`@sLlCPCt@",
             "summary" => %{
               "diffs" => %{"cheapest" => 0, "fastest" => 0},
               "distance" => %{
                 "metric" => "20.1 km",
                 "text" => "12.5 mi",
                 "value" => 20_077
               },
               "duration" => %{"text" => "28 min", "value" => 1687},
               "hasTolls" => true,
               "name" => "I-95",
               "note" => [
                 %{
                   "code" => "closure",
                   "text" => "Route is blocked",
                   "type" => "warning"
                 }
               ],
               "url" =>
                 "https://www.google.com/maps/?saddr=40.8580996,-73.9899897&daddr=40.8583903,-73.9778781+to:40.8515882,-73.9526117+to:40.8458376,-73.9301991+to:40.8291221,-73.8475227+to:40.7832664,-73.8119872&via=1,2,3,4"
             },
             "tolls" => [
               %{
                 "arrival" => %{
                   "distance" => 2310,
                   "time" => "2021-04-30T17:20:48+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" =>
                   "Discounts: Carpool plan and Green Pass discounts available. Contact Port Authority for details. ",
                 "discountCarType" => "Class 1, Class 11",
                 "height" => nil,
                 "id" => 1_119_003,
                 "lat" => 40.85445,
                 "licensePlateCost" => nil,
                 "licensePlatePrimary" => "Tolls by Mail",
                 "lng" => -73.97005,
                 "name" => "GWL : Geo Washington Br - Lower Level",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.97005, 40.85445],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 11.75,
                 "road" => "George Washington Bridge",
                 "state" => "New Jersey",
                 "tagCost" => 11.75,
                 "tagPriCost" => 11.75,
                 "tagPrimary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NJ",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "E-ZPass DE",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway",
                   "E-ZPass IN",
                   "RiverLink",
                   "E-ZPass ME"
                 ],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => nil,
                 "tagSecondary" => nil,
                 "type" => "barrier"
               },
               %{
                 "arrival" => %{
                   "distance" => 15_688,
                   "time" => "2021-04-30T17:34:00+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" => nil,
                 "discountCarType" => nil,
                 "height" => nil,
                 "id" => 1_099_005,
                 "lat" => 40.81355,
                 "licensePlateCost" => 10.17,
                 "licensePlatePrimary" => "Tolls By Mail",
                 "lng" => -73.83655,
                 "name" => "The Bronx-Whitestone Bridge",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.83655, 40.81355],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 6.55,
                 "road" => "The Bronx-Whitestone Bridge",
                 "state" => "New York",
                 "tagCost" => 6.55,
                 "tagPriCost" => 6.55,
                 "tagPrimary" => ["E-ZPass NY"],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => 8.36,
                 "tagSecondary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway",
                   "E-ZPass IN"
                 ],
                 "type" => "barrier"
               }
             ]
           },
           %{
             "costs" => %{
               "cash" => nil,
               "creditCard" => nil,
               "fuel" => 1.36,
               "licensePlate" => nil,
               "prepaidCard" => 18.3,
               "tag" => 18.3
             },
             "directions" => [
               %{
                 "distance" => 40,
                 "duration" => 14,
                 "html_instructions" =>
                   "Head toward <span class=\"toward_street\">Broad Ave</span> on <span class=\"street\">Summit Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">131 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8580996, "longitude" => -73.9899897}
               },
               %{
                 "distance" => 430,
                 "duration" => 63,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Broad Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.8583152, "longitude" => -73.9903665}
               },
               %{
                 "distance" => 806,
                 "duration" => 126,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Fort Lee Rd</span> <span class=\"number\">(CR-12)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.5 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.861727, "longitude" => -73.9879203}
               },
               %{
                 "distance" => 211,
                 "duration" => 24,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> and take ramp onto <span class=\"next-street\">Bergen Blvd</span> <span class=\"number\">(US-1/US-9/US-46)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.1 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.8577681, "longitude" => -73.9801848}
               },
               %{
                 "distance" => 2316,
                 "duration" => 169,
                 "html_instructions" =>
                   "Take <span class=\"direction\">left</span> ramp onto <span class=\"number\">I-95 N</span> <span class=\"next-street\">(New Jersey Tpke N)</span> toward <span class=\"sign\"><span lang=\"en\">G Washington Bridge</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">1.4 mi</span>.</span>",
                 "maneuver" => "bearLeft",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8583903, "longitude" => -73.9778781}
               },
               %{
                 "distance" => 2009,
                 "duration" => 138,
                 "html_instructions" =>
                   "Continue on <span class=\"number\">I-95</span> <span class=\"next-street\">(George Washington Bridge)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.2 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "adminDivisionChange",
                     "text" => "Entering <span class=\"admin_division\">New York</span>",
                     "type" => "info"
                   },
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8515882, "longitude" => -73.9526117}
               },
               %{
                 "distance" => 7367,
                 "duration" => 390,
                 "html_instructions" =>
                   "Keep <span class=\"direction\">right</span> onto <span class=\"number\">I-95</span> <span class=\"next-street\">(Cross Bronx Expy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">4.6 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.8458376, "longitude" => -73.9301991}
               },
               %{
                 "distance" => 5997,
                 "duration" => 366,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">6A</span> toward <span class=\"sign\"><span lang=\"en\">Whitestone Br</span></span> onto <span class=\"number\">I-678 S</span> <span class=\"next-street\">(Hutchinson River Pkwy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.7 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8291221, "longitude" => -73.8475227}
               },
               %{
                 "distance" => 320,
                 "duration" => 59,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">15</span> toward <span class=\"sign\"><span lang=\"en\">20 Ave</span></span> onto <span class=\"next-street\">Whitestone Expy</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7844579, "longitude" => -73.8246274}
               },
               %{
                 "distance" => 294,
                 "duration" => 68,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">20th Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7817006, "longitude" => -73.8257003}
               },
               %{
                 "distance" => 191,
                 "duration" => 24,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">Parsons Blvd</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.1 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7816899, "longitude" => -73.8222027}
               },
               %{
                 "distance" => 814,
                 "duration" => 142,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">18th Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.5 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7832992, "longitude" => -73.8214087}
               },
               %{
                 "distance" => 79,
                 "duration" => 23,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">Murray St</span>. <span class=\"distance-description\">Go for <span class=\"length\">259 ft</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7825375, "longitude" => -73.8118064}
               },
               %{
                 "distance" => 22,
                 "duration" => 3,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">17th Rd</span>. <span class=\"distance-description\">Go for <span class=\"length\">72 ft</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7832456, "longitude" => -73.8117206}
               },
               %{
                 "distance" => 0,
                 "duration" => 0,
                 "html_instructions" =>
                   "Arrive at <span class=\"street\">17th Rd</span>. Your destination is on the right.",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "previousIntersection",
                     "text" => "The last intersection is <span class=\"street\">17th Rd</span>",
                     "type" => "info"
                   },
                   %{
                     "code" => "nextIntersection",
                     "text" =>
                       "If you reach <span class=\"next-street\">150th St</span>, youâ€™ve gone too far",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.7832664, "longitude" => -73.8119872}
               }
             ],
             "polyline" =>
               "cbkxFldrbMk@jAuCkBmBgA}HkFgBiAzA}Cz@oBrBsDhA{BBi@PyADaBPcCZ_BXcATo@Xi@|@eAt@u@dBuBl@eAd@m@{AuEW}@Eo@AgCCg@@mAF_BPiBX_Bx@oCjBcErB}CpC}E^u@rDcG\\{@b@wA\\wAX{Ab@}Cn@aGX{EN_DPaCXoBNuAFmADiIz@qG~G}l@xEya@lA_Kl@cGZsAFg@VaCtEc^xAeGfBsFpA{Dd@yA~D_LT}ADsDb@cD~@uFRgAX_Cv@mFTgDJuCAiEMeD[{KM}FKcJC]GiEEcBEqJBaKJaJV_MHqGJiGvA{X|@wNbAiQT_Dj@gKXcD\\aCTiA~AoErDmI`EwIv@eBb@kAlCcGfFuKxAeDhAaDfBeHz@qFNsARoCHyBL}Gd@{PHiBd@mGPcBViBxBeLd@kBdB_JfEwS~@}EzEgVlAmGfDaPtByKbAuEdAoElAgDf@q@`@u@rAgCv@gBNc@TcAZkBHoA@{BG}BSgEy@iLMuB@kAF}@h@_D`@_Ad@u@n@o@^Wd@Ov@QtIsAnBOnBEfO?hLVdGTxELfGFlIBhAEhBU`AUbBg@lAe@rAs@nZwPvJoFll@i\\dXeOrDmB|Ak@fC]nCMp@AjET`DVhANlGnAZHrDn@rC\\|CT|At@|Bp@p@\\tCb@bCj@CqJDkD?}C}@g@wBgAkCm@Z{I@{@LuBjBqj@mCQCt@",
             "summary" => %{
               "diffs" => %{"cheapest" => 0.05, "fastest" => 1},
               "distance" => %{
                 "metric" => "20.9 km",
                 "text" => "13.0 mi",
                 "value" => 20_896
               },
               "duration" => %{"text" => "29 min", "value" => 1774},
               "hasTolls" => true,
               "name" => "I-95",
               "note" => [
                 %{
                   "code" => "closure",
                   "text" => "Route is blocked",
                   "type" => "warning"
                 }
               ],
               "url" =>
                 "https://www.google.com/maps/?saddr=40.8580996,-73.9899897&daddr=40.8583903,-73.9778781+to:40.8515882,-73.9526117+to:40.8458376,-73.9301991+to:40.8291221,-73.8475227+to:40.7832664,-73.8119872&via=1,2,3,4"
             },
             "tolls" => [
               %{
                 "arrival" => %{
                   "distance" => 2310,
                   "time" => "2021-04-30T17:20:48+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" =>
                   "Discounts: Carpool plan and Green Pass discounts available. Contact Port Authority for details. ",
                 "discountCarType" => "Class 1, Class 11",
                 "height" => nil,
                 "id" => 1_119_003,
                 "lat" => 40.85445,
                 "licensePlateCost" => nil,
                 "licensePlatePrimary" => "Tolls by Mail",
                 "lng" => -73.97005,
                 "name" => "GWL : Geo Washington Br - Lower Level",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.97005, 40.85445],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 11.75,
                 "road" => "George Washington Bridge",
                 "state" => "New Jersey",
                 "tagCost" => 11.75,
                 "tagPriCost" => 11.75,
                 "tagPrimary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NJ",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "E-ZPass DE",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway",
                   "E-ZPass IN",
                   "RiverLink"
                 ],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => nil,
                 "tagSecondary" => nil,
                 "type" => "barrier"
               },
               %{
                 "arrival" => %{
                   "distance" => 15_688,
                   "time" => "2021-04-30T17:33:58+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" => nil,
                 "discountCarType" => nil,
                 "height" => nil,
                 "id" => 1_099_005,
                 "lat" => 40.81355,
                 "licensePlateCost" => 10.17,
                 "licensePlatePrimary" => "Tolls By Mail",
                 "lng" => -73.83655,
                 "name" => "The Bronx-Whitestone Bridge",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.83655, 40.81355],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 6.55,
                 "road" => "The Bronx-Whitestone Bridge",
                 "state" => "New York",
                 "tagCost" => 6.55,
                 "tagPriCost" => 6.55,
                 "tagPrimary" => ["E-ZPass NY"],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => 8.36,
                 "tagSecondary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway"
                 ],
                 "type" => "barrier"
               }
             ]
           },
           %{
             "costs" => %{
               "cash" => nil,
               "creditCard" => nil,
               "fuel" => 1.69,
               "licensePlate" => nil,
               "prepaidCard" => 18.3,
               "tag" => 18.3
             },
             "directions" => [
               %{
                 "distance" => 40,
                 "duration" => 14,
                 "html_instructions" =>
                   "Head toward <span class=\"toward_street\">Broad Ave</span> on <span class=\"street\">Summit Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">131 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8580996, "longitude" => -73.9899897}
               },
               %{
                 "distance" => 430,
                 "duration" => 63,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Broad Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.8583152, "longitude" => -73.9903665}
               },
               %{
                 "distance" => 2091,
                 "duration" => 353,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Fort Lee Rd</span> <span class=\"number\">(CR-12)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.861727, "longitude" => -73.9879203}
               },
               %{
                 "distance" => 274,
                 "duration" => 41,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">Park Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.8509338, "longitude" => -73.9683831}
               },
               %{
                 "distance" => 67,
                 "duration" => 15,
                 "html_instructions" =>
                   "Continue on <span class=\"next-street\">Hudson St</span> toward <span class=\"sign\"><span lang=\"en\">I-95 N</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">220 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8531439, "longitude" => -73.9670634}
               },
               %{
                 "distance" => 1272,
                 "duration" => 143,
                 "html_instructions" =>
                   "Take ramp onto <span class=\"number\">I-95</span> <span class=\"next-street\">(New Jersey Tpke N)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.8 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.853734, "longitude" => -73.9669991}
               },
               %{
                 "distance" => 2003,
                 "duration" => 143,
                 "html_instructions" =>
                   "Continue on <span class=\"number\">I-95</span> <span class=\"next-street\">(George Washington Bridge)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.2 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "adminDivisionChange",
                     "text" => "Entering <span class=\"admin_division\">New York</span>",
                     "type" => "info"
                   },
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8515882, "longitude" => -73.9526117}
               },
               %{
                 "distance" => 7712,
                 "duration" => 408,
                 "html_instructions" =>
                   "Keep <span class=\"direction\">left</span> onto <span class=\"number\">I-95</span> <span class=\"next-street\">(Cross Bronx Expy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">4.8 mi</span>.</span>",
                 "maneuver" => "bearLeft",
                 "note" => [],
                 "position" => %{"latitude" => 40.8458376, "longitude" => -73.9301991}
               },
               %{
                 "distance" => 3658,
                 "duration" => 177,
                 "html_instructions" =>
                   "Keep <span class=\"direction\">right</span> onto <span class=\"number\">I-295 S</span> <span class=\"next-street\">(Cross Bronx Expy Ext)</span> toward <span class=\"sign\"><span lang=\"en\">Throgs Neck Br</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">2.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8279419, "longitude" => -73.8437998}
               },
               %{
                 "distance" => 4889,
                 "duration" => 249,
                 "html_instructions" =>
                   "Continue on <span class=\"number\">I-295</span> <span class=\"next-street\">(Throgs Neck Expy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.0 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8177173, "longitude" => -73.8035667}
               },
               %{
                 "distance" => 404,
                 "duration" => 47,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">6B</span> toward <span class=\"sign\"><span lang=\"en\">26 Ave</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7796729, "longitude" => -73.7848341}
               },
               %{
                 "distance" => 967,
                 "duration" => 135,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">26th Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.6 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7760358, "longitude" => -73.78492}
               },
               %{
                 "distance" => 1389,
                 "duration" => 184,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">slightly right</span> onto <span class=\"next-street\">Francis Lewis Blvd</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.9 mi</span>.</span>",
                 "maneuver" => "lightRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7730639, "longitude" => -73.7955952}
               },
               %{
                 "distance" => 111,
                 "duration" => 41,
                 "html_instructions" =>
                   "Make a U-Turn at <span class=\"cross_street\">17th Ave</span> onto <span class=\"next-street\">Francis Lewis Blvd</span>. <span class=\"distance-description\">Go for <span class=\"length\">364 ft</span>.</span>",
                 "maneuver" => "uTurnLeft",
                 "note" => [],
                 "position" => %{"latitude" => 40.783385, "longitude" => -73.8044679}
               },
               %{
                 "distance" => 658,
                 "duration" => 96,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">17th Rd</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.4 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7826447, "longitude" => -73.8042212}
               },
               %{
                 "distance" => 0,
                 "duration" => 0,
                 "html_instructions" =>
                   "Arrive at <span class=\"street\">17th Rd</span>. Your destination is on the right.",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "previousIntersection",
                     "text" => "The last intersection is <span class=\"street\">Murray St</span>",
                     "type" => "info"
                   },
                   %{
                     "code" => "nextIntersection",
                     "text" =>
                       "If you reach <span class=\"next-street\">150th St</span>, youâ€™ve gone too far",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.7832664, "longitude" => -73.8119872}
               }
             ],
             "polyline" =>
               "cbkxFldrbMk@jAuCkBmBgA}HkFgBiAzA}Cz@oBrBsDhA{BBi@PyADaBPcCZ_BXcATo@Xi@|@eAt@u@dBuBl@eAd@m@l@g@tBwBPMnAmA~@iAjB}Cp@qAxA_C|BaEtCyFpA_CJMpCyEvByDd@}@f@iA@I\\sDPwC\\eE_@m@cDoBoAq@eBm@OEo@CuAB_@Oc@QMYk@eBHmA`A_MlAsJp@{E\\oC~G}l@xEya@lA_KdAaKhAeJhA{JpAwKvA_GjBqFnFwPj@iCt@{CR{Ab@cD~@uFRgAX_Cv@mFTgDJuCAiEMeD[{KM}FKcJC]GiEEcBEqJBaKJaJV_MHqGJiGvA{X|@wNbAiQT_Dj@gKXcD\\aCTiA~AoErDmI`EwIv@eBb@kAlCcGfFuKxAeDhAaDfBeHz@qFNsARoCHyBL}Gd@{PHiBd@mGPcBViBxBeLd@kBdB_JfEwS~@}EzEgVlAmGfDaPtByKbAuEdAoElAgDV_A`@iAhAwCz@{CJm@VoCFkBDoBS}Ei@qHMgA]oFMuCCiBVsGZ_D~@sEdF}Qj@cCfLci@|@oDb@{AlAqDfFiMxByF~CmJdA{DtAgGv@}DlBuKdCiMr@uDXeB\\cD`AcLZqEJiBZmE^}C\\qBb@qBn@aC^mAd@qAn@yAxAqCdAaBr@aAx@cAt@w@`A}@`CkBhBgAfAi@dAa@|Bu@pAY|Ca@xBKhGE|G?vREbNGtTCdUEjDClDM`BSfB]xAc@|Am@~Au@dCyAfCqBhCmCnAaBzEyH|@sAzAoB~@aAbCwBvB_B|A}@lB{@fBm@rA_@`B[zBYdJcAzCDrFGdIRpCpNrApHf@vDxAbJj@xBfBvEV~@Ln@p@tI{DvI_@j@q@p@{ApA_Ar@uFzE}@|@{GjFiJfF_DnBiEbCiC~AyDnBCh@xC{AY~GcBpf@",
             "summary" => %{
               "avoidHighTolls" => true,
               "diffs" => %{"cheapest" => 0.38, "fastest" => 18},
               "distance" => %{
                 "metric" => "26.0 km",
                 "text" => "16.1 mi",
                 "value" => 25_965
               },
               "duration" => %{"text" => "45 min", "value" => 2749},
               "hasTolls" => true,
               "name" => "I-95",
               "note" => [
                 %{
                   "code" => "closure",
                   "text" => "Route is blocked",
                   "type" => "warning"
                 }
               ],
               "url" =>
                 "https://www.google.com/maps/?saddr=40.8580996,-73.9899897&daddr=40.853734,-73.9669991+to:40.8515882,-73.9526117+to:40.8458376,-73.9301991+to:40.8279419,-73.8437998+to:40.8177173,-73.8035667+to:40.7826447,-73.8042212+to:40.7832664,-73.8119872&via=1,2,3,4,5,6"
             },
             "tolls" => [
               %{
                 "arrival" => %{
                   "distance" => 3025,
                   "time" => "2021-04-30T17:24:21+00:00"
                 },
                 "cashCost" => 16,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" =>
                   "Discounts: Carpool plan and Green Pass discounts available. Contact Port Authority for details. ",
                 "discountCarType" => "Class 1, Class 11",
                 "height" => nil,
                 "id" => 1_119_002,
                 "lat" => 40.85395,
                 "licensePlateCost" => nil,
                 "licensePlatePrimary" => "Tolls by Mail",
                 "lng" => -73.96595,
                 "name" => "GWU : Geo Washington Br - Upper Level",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.96595, 40.85395],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 11.75,
                 "road" => "George Washington Bridge",
                 "state" => "New Jersey",
                 "tagCost" => 11.75,
                 "tagPriCost" => 11.75,
                 "tagPrimary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NJ",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "E-ZPass DE",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway",
                   "E-ZPass IN"
                 ],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => nil,
                 "tagSecondary" => nil,
                 "type" => "barrier"
               },
               %{
                 "arrival" => %{
                   "distance" => 17_704,
                   "time" => "2021-04-30T17:38:46+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" => nil,
                 "discountCarType" => nil,
                 "height" => nil,
                 "id" => 1_099_039,
                 "lat" => 40.81755,
                 "licensePlateCost" => 10.17,
                 "licensePlatePrimary" => "Tolls By Mail",
                 "lng" => -73.80165,
                 "name" => "Throgs Neck Bridge",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.80165, 40.81755],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 6.55,
                 "road" => "Throgs Neck Bridge",
                 "state" => "New York",
                 "tagCost" => 6.55,
                 "tagPriCost" => 6.55,
                 "tagPrimary" => ["E-ZPass NY"],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => 8.36,
                 "tagSecondary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "Uni",
                   "I-Pass"
                 ],
                 "type" => "barrier"
               }
             ]
           },
           %{
             "costs" => %{
               "cash" => nil,
               "creditCard" => nil,
               "fuel" => 1.88,
               "licensePlate" => nil,
               "prepaidCard" => 18.3,
               "tag" => 18.3
             },
             "directions" => [
               %{
                 "distance" => 40,
                 "duration" => 14,
                 "html_instructions" =>
                   "Head toward <span class=\"toward_street\">Broad Ave</span> on <span class=\"street\">Summit Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">131 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8580996, "longitude" => -73.9899897}
               },
               %{
                 "distance" => 430,
                 "duration" => 63,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Broad Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.8583152, "longitude" => -73.9903665}
               },
               %{
                 "distance" => 2091,
                 "duration" => 353,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Fort Lee Rd</span> <span class=\"number\">(CR-12)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.3 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.861727, "longitude" => -73.9879203}
               },
               %{
                 "distance" => 274,
                 "duration" => 41,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">Park Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.8509338, "longitude" => -73.9683831}
               },
               %{
                 "distance" => 67,
                 "duration" => 15,
                 "html_instructions" =>
                   "Continue on <span class=\"next-street\">Hudson St</span> toward <span class=\"sign\"><span lang=\"en\">I-95 N</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">220 ft</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.8531439, "longitude" => -73.9670634}
               },
               %{
                 "distance" => 1272,
                 "duration" => 143,
                 "html_instructions" =>
                   "Take ramp onto <span class=\"number\">I-95</span> <span class=\"next-street\">(New Jersey Tpke N)</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.8 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.853734, "longitude" => -73.9669991}
               },
               %{
                 "distance" => 1688,
                 "duration" => 116,
                 "html_instructions" =>
                   "Continue on <span class=\"number\">I-95</span> <span class=\"next-street\">(George Washington Bridge)</span>. <span class=\"distance-description\">Go for <span class=\"length\">1.0 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "adminDivisionChange",
                     "text" => "Entering <span class=\"admin_division\">New York</span>",
                     "type" => "info"
                   },
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8515882, "longitude" => -73.9526117}
               },
               %{
                 "distance" => 5281,
                 "duration" => 326,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">2</span> toward <span class=\"sign\"><span lang=\"en\">Harlem Riv Dr</span>/<span lang=\"en\">FDR Dr</span></span> onto <span class=\"next-street\">Harlem River Dr</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.8470392, "longitude" => -73.9335787}
               },
               %{
                 "distance" => 1205,
                 "duration" => 124,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">17</span> toward <span class=\"sign\"><span lang=\"en\">RFK Bridge</span>/<span lang=\"en\">I-278-TOLL</span>/<span lang=\"en\">Bruckner Expwy</span>/<span lang=\"en\">Grand Central Pkwy</span></span> onto <span class=\"next-street\">Robert F Kennedy Brg</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.7 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"},
                   %{
                     "code" => "tollBooth",
                     "text" => "Stop for toll booth",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.8024502, "longitude" => -73.9302957}
               },
               %{
                 "distance" => 4679,
                 "duration" => 283,
                 "html_instructions" =>
                   "Take ramp onto <span class=\"number\">I-278 W</span> <span class=\"next-street\">(Robert F Kennedy Brg)</span> toward <span class=\"sign\"><span lang=\"en\">Queens Airports</span></span>. <span class=\"distance-description\">Go for <span class=\"length\">2.9 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [
                   %{"code" => "tollRoad", "text" => "Toll road", "type" => "info"}
                 ],
                 "position" => %{"latitude" => 40.797869, "longitude" => -73.9226139}
               },
               %{
                 "distance" => 4832,
                 "duration" => 248,
                 "html_instructions" =>
                   "Continue on <span class=\"next-street\">Grand Central Pkwy E</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.0 mi</span>.</span>",
                 "maneuver" => "forward",
                 "note" => [],
                 "position" => %{"latitude" => 40.7681715, "longitude" => -73.9054048}
               },
               %{
                 "distance" => 4818,
                 "duration" => 295,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">9E</span> onto <span class=\"number\">I-678 N</span> <span class=\"next-street\">(Whitestone Expy)</span>. <span class=\"distance-description\">Go for <span class=\"length\">3.0 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7601035, "longitude" => -73.8569534}
               },
               %{
                 "distance" => 635,
                 "duration" => 51,
                 "html_instructions" =>
                   "Take <span class=\"direction\">left</span> exit <span class=\"exit\">16</span> toward <span class=\"sign\"><span lang=\"en\">Cross Is Pkwy South</span></span> onto <span class=\"next-street\">Cross Island Pkwy S</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.4 mi</span>.</span>",
                 "maneuver" => "bearLeft",
                 "note" => [],
                 "position" => %{"latitude" => 40.7868612, "longitude" => -73.8239193}
               },
               %{
                 "distance" => 544,
                 "duration" => 86,
                 "html_instructions" =>
                   "Take exit <span class=\"exit\">35</span> toward <span class=\"sign\"><span lang=\"en\">14 Ave</span>/<span lang=\"en\">Francis Lewis Blvd</span></span> onto <span class=\"next-street\">Cross Island Pkwy</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.3 mi</span>.</span>",
                 "maneuver" => "bearRight",
                 "note" => [],
                 "position" => %{"latitude" => 40.7890391, "longitude" => -73.8190806}
               },
               %{
                 "distance" => 321,
                 "duration" => 58,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">150th St</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.2 mi</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7869899, "longitude" => -73.813405}
               },
               %{
                 "distance" => 185,
                 "duration" => 31,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">left</span> onto <span class=\"next-street\">17th Ave</span>. <span class=\"distance-description\">Go for <span class=\"length\">0.1 mi</span>.</span>",
                 "maneuver" => "left",
                 "note" => [],
                 "position" => %{"latitude" => 40.7841253, "longitude" => -73.8138127}
               },
               %{
                 "distance" => 79,
                 "duration" => 15,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">Murray St</span>. <span class=\"distance-description\">Go for <span class=\"length\">259 ft</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7839644, "longitude" => -73.8116348}
               },
               %{
                 "distance" => 22,
                 "duration" => 3,
                 "html_instructions" =>
                   "Turn <span class=\"direction\">right</span> onto <span class=\"next-street\">17th Rd</span>. <span class=\"distance-description\">Go for <span class=\"length\">72 ft</span>.</span>",
                 "maneuver" => "right",
                 "note" => [],
                 "position" => %{"latitude" => 40.7832456, "longitude" => -73.8117206}
               },
               %{
                 "distance" => 0,
                 "duration" => 0,
                 "html_instructions" =>
                   "Arrive at <span class=\"street\">17th Rd</span>. Your destination is on the right.",
                 "maneuver" => "forward",
                 "note" => [
                   %{
                     "code" => "previousIntersection",
                     "text" => "The last intersection is <span class=\"street\">17th Rd</span>",
                     "type" => "info"
                   },
                   %{
                     "code" => "nextIntersection",
                     "text" =>
                       "If you reach <span class=\"next-street\">150th St</span>, youâ€™ve gone too far",
                     "type" => "info"
                   }
                 ],
                 "position" => %{"latitude" => 40.7832664, "longitude" => -73.8119872}
               }
             ],
             "polyline" =>
               "cbkxFldrbMk@jAuCkBmBgA}HkFgBiAzA}Cz@oBrBsDhA{BBi@PyADaBPcCZ_BXcATo@Xi@|@eAt@u@dBuBl@eAd@m@l@g@tBwBPMnAmA~@iAjB}Cp@qAxA_C|BaEtCyFpA_CJMpCyEvByDd@}@f@iA@I\\sDPwC\\eE_@m@cDoBoAq@eBm@OEo@CuAB_@Oc@QMYk@eBHmA`A_MlAsJp@{E\\oC~G}l@xEya@lA_KdAaKhAeJhA{JpAwKvA_GjBqFtBuGrAmCfCiI^m@t@w@d@?b@FRFXPhCjBhA\\p@H\\?bCQ^AZ@jC\\t@TdEvBbIzD`F~B~I|D|@ZxAZt@J~ANn@B~CBdGOxMm@rE_@jCOp@A|AQfDS|FSvAA~@BrB?bHUlBB|AFtA@xCEjDMr@?xCc@zBSdB@~Mr@bMh@|BT~@NdFp@pAFhBCvBa@rBs@r@Yn@]vCmBz@o@~C{C`C_ChDyCfBkAfCmAp@[fB_@`ADbBPPALEv@k@NGx@K\\DVTJVDXCb@I^[p@WVUJW@SEOKMKMUKm@?YPgAr@_CPe@rH}UzB}GnBuEfA_Cv@eAfAgAb@Yz@S^?l@Fl@TrJhG~CjBfCrAxCjC~N|LxDdD`DjCtBhBnAdApAx@hAb@r@PnAPv@DlBIvAW|@[j@Y`@WrMcJtDoCdJkGjJuGdGcEzAiAzAsAXYnA}AdEuGbBgC|AgC~@cBt@kA~CoE^u@VaAHi@f@yFRqBl@iHxBcSF{@LeDFeDJcC`@yC`AiFp@uE`@kF`Dq^xBmXNsBHsADyBAoEM}Cq@eJo@iFyBqLy@gDW{@i@kBw@cCs@sBcAcCwC}G_EuIiAiDa@eB_AyFSqBMuBMaEAcB@sARiEb@}DHg@f@_CXgA`@mAt@kBfAeCrC_FlDoFfFyGpAyAhG{FlHwFzFeEvEuDx@{@\\_@t@eAdAiB|@uBjAkDbAkBl@aA\\]VSx@e@|DcBr@_@PQf@m@\\m@Jc@Hq@Bi@CcA_@oDy@kFi@}CuA}Fy@gCaAeCe@aAk@eAm@y@e@c@wAcBiA}A[SsBqDy@_B}@}B_DqJm@yAk@cAy@iA{@_Ae@c@_@[cAm@{HoDg@WyAq@yByAcAw@}@s@aBwAaEsEq@eAi@q@w@kA_A{AaCqEeG}LiAiByAkBaCmCq@o@_CcBoBkAaCmAyNeHgAe@iCoA_EgBwCgAiBi@uEaAsBY}BWiD[mC[wFg@yDw@uBUgAU_@Qg@_@_@a@Wc@Qa@Ka@Ki@Gu@Aq@FmBLmAVcB`@yBf@{Bf@iAjCuEZq@p@aC|@kCj@qBPkBZoHr@D`CVvF\\lCR`@sLlCPCt@",
             "summary" => %{
               "avoidHighTolls" => true,
               "diffs" => %{"cheapest" => 0.57, "fastest" => 12},
               "distance" => %{
                 "metric" => "28.5 km",
                 "text" => "17.7 mi",
                 "value" => 28_463
               },
               "duration" => %{"text" => "40 min", "value" => 2433},
               "hasTolls" => true,
               "name" => "Grand Central Pkwy E",
               "note" => [
                 %{
                   "code" => "closure",
                   "text" => "Route is blocked",
                   "type" => "warning"
                 }
               ],
               "url" =>
                 "https://www.google.com/maps/?saddr=40.8580996,-73.9899897&daddr=40.853734,-73.9669991+to:40.8515882,-73.9526117+to:40.8470392,-73.9335787+to:40.8024502,-73.9302957+to:40.797869,-73.9226139+to:40.7681715,-73.9054048+to:40.7601035,-73.8569534+to:40.7832664,-73.8119872&via=1,2,3,4,5,6,7"
             },
             "tolls" => [
               %{
                 "arrival" => %{
                   "distance" => 3025,
                   "time" => "2021-04-30T17:24:21+00:00"
                 },
                 "cashCost" => 16,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" =>
                   "Discounts: Carpool plan and Green Pass discounts available. Contact Port Authority for details. ",
                 "discountCarType" => "Class 1, Class 11",
                 "height" => nil,
                 "id" => 1_119_002,
                 "lat" => 40.85395,
                 "licensePlateCost" => nil,
                 "licensePlatePrimary" => "Tolls by Mail",
                 "lng" => -73.96595,
                 "name" => "GWU : Geo Washington Br - Upper Level",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.96595, 40.85395],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 11.75,
                 "road" => "George Washington Bridge",
                 "state" => "New Jersey",
                 "tagCost" => 11.75,
                 "tagPriCost" => 11.75,
                 "tagPrimary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NJ",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "E-ZPass DE",
                   "Uni",
                   "I-Pass",
                   "E-ZPass Skyway"
                 ],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => nil,
                 "tagSecondary" => nil,
                 "type" => "barrier"
               },
               %{
                 "arrival" => %{
                   "distance" => 12_091,
                   "time" => "2021-04-30T17:35:30+00:00"
                 },
                 "cashCost" => nil,
                 "country" => "USA",
                 "creditCardCost" => nil,
                 "currency" => "USD",
                 "discountCarDetails" => nil,
                 "discountCarType" => nil,
                 "height" => nil,
                 "id" => 1_099_048,
                 "lat" => 40.79925,
                 "licensePlateCost" => 10.17,
                 "licensePlatePrimary" => "Tolls By Mail",
                 "lng" => -73.92505,
                 "name" => "Triborough (Robert F. Kennedy Bridge)",
                 "point" => %{
                   "geometry" => %{
                     "coordinates" => [-73.92505, 40.79925],
                     "type" => "Point"
                   },
                   "properties" => %{},
                   "type" => "Feature"
                 },
                 "prepaidCardCost" => 6.55,
                 "road" => "Triborough (Robert F. Kennedy Bridge)",
                 "state" => "New York",
                 "tagCost" => 6.55,
                 "tagPriCost" => 6.55,
                 "tagPrimary" => ["E-ZPass NY"],
                 "tagRequested" => "prepaidCardCost",
                 "tagSecCost" => 8.36,
                 "tagSecondary" => [
                   "E-ZPass MA",
                   "E-ZPass NH",
                   "E-ZPass NY",
                   "E-ZPass NC",
                   "E-ZPass OH",
                   "E-ZPass PA",
                   "E-ZPass RI",
                   "E-ZPass VA",
                   "E-ZPass WV",
                   "E-ZPass",
                   "Uni"
                 ],
                 "type" => "barrier"
               }
             ]
           }
         ],
         "status" => "OK",
         "summary" => %{
           "countries" => ["USA"],
           "currency" => "USD",
           "departure_time" => 1_619_802_959,
           "fuelEfficiency" => %{"city" => 23.4, "hwy" => 30, "units" => "mpg"},
           "fuelPrice" => %{
             "currency" => "USD",
             "fuelUnit" => "gallon",
             "value" => 2.8
           },
           "rates" => %{
             "ARS" => 6.13595,
             "AUD" => 1.28635,
             "CAD" => 1.227755,
             "CLF" => 6.13595,
             "CLP" => 6.13595,
             "COP" => 6.13595,
             "DKK" => 6.13595,
             "EUR" => 0.825175,
             "GBP" => 0.71665,
             "INR" => 74.143505,
             "MXN" => 20.05329,
             "NOK" => 8.197298,
             "PEN" => 6.13595,
             "SEK" => 8.375992,
             "SOL" => 6.13595,
             "USD" => 1
           },
           "route" => [
             %{
               "address" => "215 Broad Ave, Leonia, NJ 07605, United States",
               "location" => %{"lat" => 40.85793, "lng" => -73.99016}
             },
             %{
               "address" => "17-18 Murray St, Whitestone, NY 11357, United States",
               "location" => %{"lat" => 40.78339, "lng" => -73.81197}
             }
           ],
           "share" => %{
             "name" => "leonia,nj-whitestone,ny",
             "prefix" => "leonia%2Cnj-whitestone%2Cny",
             "uuid" => "5da44c9e-7990-43c5-93aa-7319919197ee"
           },
           "source" => "HERE",
           "units" => %{
             "currencyUnit" => "USD",
             "fuelEfficiencyUnit" => %{
               "city" => 23.4,
               "fuelUnit" => "gallon",
               "hwy" => 30,
               "units" => "mpg"
             }
           },
           "vehicleType" => "2AxlesAuto"
         }
       }}
end
