#!/bin/bash
curl --location --request POST 'http://localhost:4000/api/v1.1/estimates' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--header 'Authorization: Bearer {{ShipperToken}}' \
-d 'origin_address=1266%20Norman%20Ave%20Cincinnati%20OH%2045231&destination_address=641%20Evangeline%20Rd%20Cincinnati%20OH%2045240&vehicle_class=1&weight=25&service_level=1'