defmodule FraytElixir.Test.FakeHubspot do
  def call_api(
        :post,
        "/crm/v3/objects/companies",
        %{properties: %{start_shipping: "invalid_answer"}},
        _
      ),
      do:
        {:error, 400,
         %{
           "category" => "VALIDATION_ERROR"
         }}

  def call_api(:post, "/crm/v3/objects/companies", %{properties: body}, _),
    do:
      {:ok,
       %{
         "createdAt" => DateTime.utc_now(),
         "archived" => false,
         "id" => "new_company",
         "properties" => %{
           "city" => Map.get(body, :city),
           "createdate" => DateTime.utc_now(),
           "domain" => nil,
           "hs_lastmodifieddate" => DateTime.utc_now(),
           "industry" => nil,
           "name" => Map.get(body, :name),
           "phone" => Map.get(body, :phone),
           "state" => Map.get(body, :state),
           "numberofemployees" => Map.get(body, :numberofemployees),
           "monthly_shipments" => Map.get(body, :monthly_shipments),
           "start_shipping" => Map.get(body, :start_shipping),
           "api_integration" => Map.get(body, :api_integration),
           "schedule_demo" => Map.get(body, :schedule_demo)
         },
         "updatedAt" => DateTime.utc_now()
       }}

  def call_api(:post, "/crm/v3/objects/contacts", %{properties: body}, _),
    do:
      {:ok,
       %{
         "createdAt" => DateTime.utc_now(),
         "archived" => false,
         "id" => "new_contact",
         "properties" => %{
           "createdate" => DateTime.utc_now(),
           "email" => Map.get(body, :email),
           "firstname" => Map.get(body, :firstname),
           "lastmodifieddate" => DateTime.utc_now(),
           "lastname" => Map.get(body, :lastname),
           "phone" => Map.get(body, :phone),
           "referrer" => Map.get(body, :referrer),
           "city" => Map.get(body, :city),
           "state" => Map.get(body, :state)
         },
         "updatedAt" => DateTime.utc_now()
       }}

  def call_api(:patch, "/crm/v3/objects/contacts/" <> _ = url, _, opts),
    do: call_api(:get, url, %{}, opts)

  def call_api(
        :put,
        "/crm/v3/objects/companies/new_company/associations/contacts/new_contact/company_to_contact",
        %{},
        _
      ) do
    {:ok,
     %{
       "archived" => false,
       "associations" => %{
         "contacts" => %{"results" => [%{"id" => "new_contact", "type" => "company_to_contact"}]}
       },
       "createdAt" => DateTime.utc_now(),
       "id" => "new_company",
       "properties" => %{
         "createdate" => DateTime.utc_now(),
         "hs_lastmodifieddate" => DateTime.utc_now(),
         "hs_object_id" => "4781732756"
       },
       "updatedAt" => DateTime.utc_now()
     }}
  end

  def call_api(
        :post,
        "/oauth/v1/token",
        %{
          code: "super_duper_valid_code"
        },
        _
      ) do
    {:ok,
     %{
       "expires_in" => 60_000,
       "refresh_token" => "super_duper_valid_refresh_token",
       "access_token" => "super_duper_valid_access_token"
     }}
  end

  def call_api(
        :post,
        "/oauth/v1/token",
        %{
          refresh_token: "super_duper_valid_refresh_token" <> _
        },
        _
      ) do
    {:ok,
     %{
       "expires_in" => 60_000,
       "refresh_token" => "super_duper_valid_refresh_token",
       "access_token" => "super_duper_valid_access_token"
     }}
  end

  def call_api(:post, "/oauth/v1/token", _, _),
    do:
      {:error, 400,
       %{
         "status" => "BAD_AUTH_CODE",
         "message" => "missing or unknown auth code",
         "correlationId" => "60270ae6-e9f5-427a-a4ca-4b2d8124c832"
       }}

  def call_api(:get, "/oauth/v1/refresh-tokens/" <> _token, _, _),
    do:
      {:ok,
       %{
         "hub_id" => 19_653_124,
         "hub_domain" => "domain.hubspot.com"
       }}

  def call_api(
        :post,
        "/crm/v3/objects/contacts/search",
        %{
          filterGroups: [%{filters: [%{"value" => "101" <> _ = email, "propertyName" => :email}]}]
        },
        _
      ),
      do:
        {:ok,
         %{
           "total" => 1,
           "results" => [
             %{
               "id" => "found_contact",
               "properties" => %{
                 "createdate" => "2021-04-21T21:54:27.178Z",
                 "email" => email,
                 "firstname" => "Friedrich",
                 "hs_object_id" => "found_contact",
                 "lastmodifieddate" => "2021-04-21T21:54:40.596Z",
                 "lastname" => "Brandenburg"
               },
               "createdAt" => "2021-04-21T21:54:27.178Z",
               "updatedAt" => "2021-04-21T21:54:40.596Z",
               "archived" => false
             }
           ]
         }}

  def call_api(
        :post,
        "/crm/v3/objects/contacts/search",
        %{
          filterGroups: [%{filters: [%{"value" => "404" <> _ = email, "propertyName" => :email}]}]
        },
        _
      ),
      do:
        {:ok,
         %{
           "total" => 1,
           "results" => [
             %{
               "id" => "ownerless_contact",
               "properties" => %{
                 "createdate" => "2021-04-21T21:54:27.178Z",
                 "email" => email,
                 "firstname" => "Friedrich",
                 "hs_object_id" => "ownerless_contact",
                 "lastmodifieddate" => "2021-04-21T21:54:40.596Z",
                 "lastname" => "Brandenburg"
               },
               "createdAt" => "2021-04-21T21:54:27.178Z",
               "updatedAt" => "2021-04-21T21:54:40.596Z",
               "archived" => false
             }
           ]
         }}

  def call_api(:post, "/crm/v3/objects/contacts/search", _, _),
    do: {:ok, %{"total" => 0, "results" => []}}

  def call_api(:get, "/crm/v3/objects/contacts/" <> params, _, _) do
    %URI{path: contact_id, query: query} = URI.parse(params)

    properties =
      case URI.decode_query(query || "") do
        %{"properties" => props} ->
          props
          |> String.split(",")
          |> Enum.map(fn prop ->
            {prop, if(contact_id == "ownerless_contact", do: nil, else: "contact_hubspot_owner")}
          end)
          |> Enum.into(%{})

        _ ->
          %{
            "email" => "#{contact_id}@frayt.com",
            "firstname" => "Friedrich",
            "lastname" => "Brandenburg"
          }
      end
      |> Map.merge(%{
        "createdate" => "2021-04-21T21:54:27.178Z",
        "hs_object_id" => contact_id,
        "lastmodifieddate" => "2021-04-21T21:54:40.596Z"
      })

    {:ok,
     %{
       "id" => contact_id,
       "properties" => properties,
       "createdAt" => "2021-04-21T21:54:27.178Z",
       "updatedAt" => "2021-04-21T21:54:40.596Z",
       "archived" => false,
       "associations" => %{
         "companies" => %{
           "results" => [
             %{
               "id" => "queried_company",
               "type" => "contact_to_company"
             }
           ]
         }
       }
     }}
  end

  def call_api(:get, "/crm/v3/objects/companies/0" <> _, _, _),
    do: raise(HTTPoison.Error, reason: :timeout)

  def call_api(:get, "/crm/v3/objects/companies/" <> params, _, _) do
    %URI{path: company_id, query: query} = URI.parse(params)

    properties =
      case URI.decode_query(query) do
        %{"properties" => props} ->
          props
          |> String.split(",")
          |> Enum.map(fn prop ->
            {prop, "hubspot_owner"}
          end)
          |> Enum.into(%{})

        _ ->
          %{
            "domain" => "frayt.com",
            "name" => "Frayt",
            "hs_object_id" => company_id
          }
      end
      |> Map.merge(%{
        "createdate" => "2021-04-21T21:53:42.338Z",
        "hs_lastmodifieddate" => "2021-04-21T21:54:43.043Z",
        "name" => "Frayt"
      })

    {:ok,
     %{
       "id" => company_id,
       "properties" => properties,
       "createdAt" => "2021-04-21T21:53:42.338Z",
       "updatedAt" => "2021-04-21T21:54:43.043Z",
       "archived" => false,
       "associations" => %{
         "contacts" => %{
           "results" => [
             %{
               "id" => "queried_contact",
               "type" => "company_to_contact"
             }
           ]
         }
       }
     }}
  end

  def call_api(:get, "/crm/v3/owners/0" <> _, _, _), do: {:error, 404, "<html>404</html>"}

  def call_api(:get, "/crm/v3/owners/" <> owner_id, _, _),
    do:
      {:ok,
       %{
         "firstName" => "John",
         "lastName" => "Smith",
         "createdAt" => "2019-10-30T03:30:17.883Z",
         "archived" => false,
         "teams" => [
           %{
             "id" => "178588",
             "name" => "Frayt"
           }
         ],
         "id" => owner_id,
         "userId" => 1_296_619,
         "email" => owner_id <> "@frayt.com",
         "updatedAt" => "2019-12-07T16:50:06.678Z"
       }}
end
