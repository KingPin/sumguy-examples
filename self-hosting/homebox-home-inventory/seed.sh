#!/usr/bin/env bash
# Seed a fresh Homebox with one user, a location tree, an item, and receipt/warranty attachments.
# Usage: ./seed.sh [base_url]   (needs curl and jq)
set -euo pipefail
HB="${1:-http://localhost:3190}"
API="$HB/api/v1"
EMAIL="you@example.com"
PASS="correct-horse-battery"
JSON=(-H "Content-Type: application/json")

# 1. Register (HTTP 204 on success; ignore the error if the user already exists)
curl -s -o /dev/null -X POST "$API/users/register" "${JSON[@]}" \
  -d "{\"name\":\"Demo\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" || true

# 2. Log in. The token already includes the "Bearer " prefix.
TOKEN=$(curl -sf -X POST "$API/users/login" "${JSON[@]}" \
  -d "{\"username\":\"$EMAIL\",\"password\":\"$PASS\"}" | jq -r .token)
AUTH=(-H "Authorization: $TOKEN")

# 3. Entity types: v0.27 stores items and locations as "entities" with a type
TYPES=$(curl -sf "$API/entity-types" "${AUTH[@]}")
ITEM_TYPE=$(jq -r '.[]|select(.isLocation|not)|.id' <<<"$TYPES" | head -1)
LOC_TYPE=$(jq -r '.[]|select(.isLocation)|.id' <<<"$TYPES" | head -1)

post() { curl -sf -X POST "$API/$1" "${AUTH[@]}" "${JSON[@]}" -d "$2"; }

# 4. Location tree: Garage > Shelf A > Box 3
GARAGE=$(post entities "{\"name\":\"Garage\",\"entityTypeId\":\"$LOC_TYPE\"}" | jq -r .id)
SHELF=$(post entities "{\"name\":\"Shelf A\",\"entityTypeId\":\"$LOC_TYPE\",\"parentId\":\"$GARAGE\"}" | jq -r .id)
BOX=$(post entities "{\"name\":\"Box 3: Cables\",\"entityTypeId\":\"$LOC_TYPE\",\"parentId\":\"$SHELF\"}" | jq -r .id)

# 5. Items inside the box
ITEM=$(post entities "{\"name\":\"HDMI 2.1 cable\",\"entityTypeId\":\"$ITEM_TYPE\",\"parentId\":\"$BOX\",\"quantity\":2}" | jq -r .id)
DISHWASHER=$(post entities "{\"name\":\"Dishwasher\",\"entityTypeId\":\"$ITEM_TYPE\",\"parentId\":\"$GARAGE\",\"manufacturer\":\"ExampleCo\",\"modelNumber\":\"DW-100\"}" | jq -r .id)

# 6. Warranty and purchase fields: read the item, change fields, PUT it back
curl -sf "$API/entities/$DISHWASHER" "${AUTH[@]}" \
  | jq '.purchaseDate="2024-03-01" | .purchasePrice=649 | .purchaseFrom="Example Appliances"
        | .warrantyExpires="2027-03-01" | .warrantyDetails="Parts and labor, call 555-0100"
        | .serialNumber="SN-EXAMPLE-0001" | .parentId=.parent.id | .entityTypeId=.entityType.id' \
  | curl -sf -X PUT "$API/entities/$DISHWASHER" "${AUTH[@]}" "${JSON[@]}" -d @- >/dev/null

# 7. Attachments: type is one of attachment, photo, manual, warranty, receipt
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'Receipt: Example Appliances, DW-100, $649.00, 2024-03-01\n' > "$TMP/receipt.txt"
printf 'Warranty: 3 years parts and labor\n' > "$TMP/warranty.txt"
for t in receipt warranty; do
  curl -sf -X POST "$API/entities/$DISHWASHER/attachments" "${AUTH[@]}" \
    -F "file=@$TMP/$t.txt" -F "type=$t" -F "name=$t.txt" >/dev/null
done

# 8. Maintenance entry
post "entities/$DISHWASHER/maintenance" '{"name":"Clean filter","description":"Rinse the bottom filter","scheduledDate":"2027-01-01"}' >/dev/null

# 9. Look the dishwasher up by asset ID, and fetch a QR code and a label
ASSET=$(curl -sf "$API/entities/$DISHWASHER" "${AUTH[@]}" | jq -r .assetId)
echo "Dishwasher asset ID: $ASSET"
curl -sf "$API/assets/$ASSET" "${AUTH[@]}" | jq '{total, item: .items[0].name}'
curl -sf -o qr.jpg "$API/qrcode?data=$HB/item/$DISHWASHER" "${AUTH[@]}"
curl -sf -o label.png "$API/labelmaker/item/$DISHWASHER?print=false" "${AUTH[@]}" || echo "label endpoint needs different params"
file qr.jpg label.png 2>/dev/null || true
echo "Open $HB (login: $EMAIL / $PASS)"
