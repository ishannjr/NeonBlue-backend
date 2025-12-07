#!/bin/bash

set -e

BASE_URL="${API_URL:-http://localhost:8000}"

echo "=============================================="
echo "Experimentation API - Example Usage"
echo "Base URL: $BASE_URL"
echo "=============================================="
echo ""

echo ">>> 1. Health Check"
curl -s "$BASE_URL/health" | python3 -m json.tool
echo ""

echo ">>> 2. Get JWT Token (Login as admin)"
TOKEN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}')
echo "$TOKEN_RESPONSE" | python3 -m json.tool

TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
AUTH_HEADER="Authorization: Bearer $TOKEN"
echo "Token obtained successfully!"
echo ""

echo ">>> 3. Create Experiment (Button Color Test)"
EXPERIMENT_RESPONSE=$(curl -s -X POST "$BASE_URL/experiments" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Button Color Test",
    "description": "Testing whether blue or green CTA buttons drive more conversions",
    "variants": [
      {
        "name": "control",
        "description": "Blue button (current)",
        "traffic_allocation": 50,
        "config": {"button_color": "blue"}
      },
      {
        "name": "treatment",
        "description": "Green button (new)",
        "traffic_allocation": 50,
        "config": {"button_color": "green"}
      }
    ]
  }')
echo "$EXPERIMENT_RESPONSE" | python3 -m json.tool

EXPERIMENT_ID=$(echo "$EXPERIMENT_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "Created experiment ID: $EXPERIMENT_ID"
echo ""

echo ">>> 4. List All Experiments"
curl -s "$BASE_URL/experiments" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo ">>> 5. Get Experiment Details"
curl -s "$BASE_URL/experiments/$EXPERIMENT_ID" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo ">>> 6. Start Experiment (Status: draft -> running)"
curl -s -X PATCH "$BASE_URL/experiments/$EXPERIMENT_ID" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"status": "running"}' | python3 -m json.tool
echo ""

echo ">>> 7. Assign Users to Variants"
echo ""

echo "--- User 'user-001' first assignment:"
ASSIGNMENT_1=$(curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/assignment/user-001" \
  -H "$AUTH_HEADER")
echo "$ASSIGNMENT_1" | python3 -m json.tool
VARIANT_1=$(echo "$ASSIGNMENT_1" | python3 -c "import sys, json; print(json.load(sys.stdin)['variant_name'])")
IS_NEW_1=$(echo "$ASSIGNMENT_1" | python3 -c "import sys, json; print(json.load(sys.stdin)['is_new_assignment'])")
echo "Assigned to: $VARIANT_1 (is_new_assignment: $IS_NEW_1)"
echo ""

echo "--- User 'user-001' second assignment (IDEMPOTENCY TEST):"
ASSIGNMENT_1B=$(curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/assignment/user-001" \
  -H "$AUTH_HEADER")
echo "$ASSIGNMENT_1B" | python3 -m json.tool
VARIANT_1B=$(echo "$ASSIGNMENT_1B" | python3 -c "import sys, json; print(json.load(sys.stdin)['variant_name'])")
IS_NEW_1B=$(echo "$ASSIGNMENT_1B" | python3 -c "import sys, json; print(json.load(sys.stdin)['is_new_assignment'])")
echo "Assigned to: $VARIANT_1B (is_new_assignment: $IS_NEW_1B)"

if [ "$VARIANT_1" = "$VARIANT_1B" ] && [ "$IS_NEW_1B" = "False" ]; then
  echo "✓ IDEMPOTENCY VERIFIED: Same variant returned, is_new_assignment=False"
else
  echo "✗ IDEMPOTENCY FAILED"
fi
echo ""

echo "--- Assigning additional test users..."
for i in {2..10}; do
  curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/assignment/user-$(printf "%03d" $i)" \
    -H "$AUTH_HEADER" > /dev/null
done
echo "Assigned users user-002 through user-010"
echo ""

echo ">>> 8. Record Events"
echo ""

echo "--- Recording a click event for user-001:"
curl -s -X POST "$BASE_URL/events" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-001",
    "event_type": "click",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "properties": {
      "button_id": "cta-main",
      "page": "/pricing"
    }
  }' | python3 -m json.tool
echo ""

echo "--- Recording a purchase event for user-001:"
curl -s -X POST "$BASE_URL/events" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-001",
    "event_type": "purchase",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "properties": {
      "order_total": 99.99,
      "currency": "USD",
      "items": 3
    }
  }' | python3 -m json.tool
echo ""

echo "--- Recording batch events:"
curl -s -X POST "$BASE_URL/events/batch" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "user_id": "user-002",
        "event_type": "click",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "properties": {"page": "/home"}
      },
      {
        "user_id": "user-002",
        "event_type": "signup",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "properties": {"plan": "pro"}
      },
      {
        "user_id": "user-003",
        "event_type": "click",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "properties": {"page": "/features"}
      },
      {
        "user_id": "user-004",
        "event_type": "purchase",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "properties": {"order_total": 49.99}
      }
    ]
  }' | python3 -m json.tool
echo ""

echo ">>> 9. Query Events"
echo ""

echo "--- List recent events:"
curl -s "$BASE_URL/events?limit=5" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo "--- List event types:"
curl -s "$BASE_URL/events/types" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo ">>> 10. Get Experiment Results"
echo ""

echo "--- Full results:"
curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/results" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo "--- Summary only (for dashboards):"
curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/results?format=summary" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo "--- Filter by event type (purchases only):"
curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/results?event_types=purchase" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo ">>> 11. Export Experiment Data"
curl -s "$BASE_URL/experiments/$EXPERIMENT_ID/results/export" \
  -H "$AUTH_HEADER" | python3 -m json.tool
echo ""

echo ">>> 12. Authentication Error Examples"
echo ""

echo "--- Missing token (should return 403):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/experiments" 2>&1 | head -5
echo ""

echo "--- Invalid token (should return 401):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/experiments" \
  -H "Authorization: Bearer invalid-token" 2>&1 | head -5
echo ""

echo ">>> 13. Complete the Experiment"
curl -s -X PATCH "$BASE_URL/experiments/$EXPERIMENT_ID" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}' | python3 -m json.tool
echo ""

echo "=============================================="
echo "Example script completed successfully!"
echo "=============================================="
