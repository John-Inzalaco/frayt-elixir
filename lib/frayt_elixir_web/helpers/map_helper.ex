defmodule FraytElixirWeb.MapHelper do
  alias FraytElixir.Accounts.{User, AdminUser}

  @colors %{
    background: "#1a1a1a",
    text: "#fcfcfc",
    foreground: "#6b6b6b",
    water: "#798af7",
    park: "#154027",
    parkText: "#00c751",
    midground: "#252525"
  }

  def get_map_styles(%User{admin: %AdminUser{site_theme: :dark}}),
    do:
      Jason.encode!([
        %{elementType: "geometry", stylers: [%{color: @colors.background}]},
        %{elementType: "labels.text.stroke", stylers: [%{color: @colors.background}]},
        %{elementType: "labels.text.fill", stylers: [%{color: @colors.foreground}]},
        %{
          featureType: "administrative.locality",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.text}]
        },
        %{
          featureType: "poi",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.text}]
        },
        %{
          featureType: "poi.park",
          elementType: "geometry",
          stylers: [%{color: @colors.park}]
        },
        %{
          featureType: "poi.park",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.parkText}]
        },
        %{
          featureType: "road",
          elementType: "geometry",
          stylers: [%{color: @colors.midground}]
        },
        %{
          featureType: "road",
          elementType: "geometry.stroke",
          stylers: [%{color: @colors.midground}]
        },
        %{
          featureType: "road",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.foreground}]
        },
        %{
          featureType: "road.highway",
          elementType: "geometry",
          stylers: [%{color: @colors.foreground}]
        },
        %{
          featureType: "road.highway",
          elementType: "geometry.stroke",
          stylers: [%{color: @colors.foreground}]
        },
        %{
          featureType: "road.highway",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.text}]
        },
        %{
          featureType: "transit",
          elementType: "geometry",
          stylers: [%{color: @colors.midground}]
        },
        %{
          featureType: "transit.station",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.text}]
        },
        %{
          featureType: "water",
          elementType: "geometry",
          stylers: [%{color: @colors.water}]
        },
        %{
          featureType: "water",
          elementType: "labels.text.fill",
          stylers: [%{color: @colors.text}]
        },
        %{
          featureType: "water",
          elementType: "labels.text.stroke",
          stylers: [%{color: @colors.water}]
        }
      ])

  def get_map_styles(_user), do: Jason.encode!([])
end
