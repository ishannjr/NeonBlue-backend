# Experiments API - Curl Commands Reference

## Authentication Setup

First, get a JWT token (required for all endpoints):

```bash
# Get JWT token
TOKEN=$(curl -s -X POST http://localhost:8000/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: $TOKEN"
```

---

## 1. CREATE EXPERIMENT

**Endpoint:** `POST /experiments`

**What happens:**
- Creates a new experiment in `draft` status
- Creates all variants linked to this experiment
- Validates that traffic allocations sum to 100%
- Validates at least 2 variants exist

```bash
curl -X POST http://localhost:8000/experiments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Homepage Hero Test",
    "description": "Testing different hero banner designs",
    "variants": [
      {
        "name": "control",
        "description": "Current hero with image",
        "traffic_allocation": 33.33,
        "config": {"hero_type": "image", "cta_text": "Get Started"}
      },
      {
        "name": "video_hero",
        "description": "Hero with background video",
        "traffic_allocation": 33.33,
        "config": {"hero_type": "video", "cta_text": "Get Started"}
      },
      {
        "name": "minimal_hero",
        "description": "Minimal text-only hero",
        "traffic_allocation": 33.34,
        "config": {"hero_type": "minimal", "cta_text": "Start Free Trial"}
      }
    ]
  }'
```

**Response:** Full experiment object with generated `id`, all variants with their IDs, `status: draft`

---

## 2. LIST EXPERIMENTS

**Endpoint:** `GET /experiments`

**What happens:**
- Returns paginated list of all experiments
- Can filter by status
- Includes all variants for each experiment

```bash
# List all experiments
curl -X GET "http://localhost:8000/experiments" \
  -H "Authorization: Bearer $TOKEN"

# List only running experiments
curl -X GET "http://localhost:8000/experiments?status=running" \
  -H "Authorization: Bearer $TOKEN"

# List with pagination (get 10 experiments, skip first 5)
curl -X GET "http://localhost:8000/experiments?limit=10&offset=5" \
  -H "Authorization: Bearer $TOKEN"

# List only draft experiments
curl -X GET "http://localhost:8000/experiments?status=draft" \
  -H "Authorization: Bearer $TOKEN"
```

**Response:** `{"experiments": [...], "total": 5}`

---

## 3. GET SINGLE EXPERIMENT

**Endpoint:** `GET /experiments/{id}`

**What happens:**
- Fetches one experiment by ID
- Returns 404 if not found
- Includes all variant details

```bash
# Get experiment with ID 1
curl -X GET http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN"
```

**Response:** Full experiment object with variants

---

## 4. START EXPERIMENT (Update Status)

**Endpoint:** `PATCH /experiments/{id}`

**What happens:**
- Changes status from `draft` → `running`
- Sets `started_at` timestamp
- Now users can be assigned to variants

```bash
# Start an experiment (draft → running)
curl -X PATCH http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "running"}'
```

**Response:** Updated experiment with `status: running` and `started_at` timestamp

---

## 5. PAUSE EXPERIMENT

**Endpoint:** `PATCH /experiments/{id}`

**What happens:**
- Changes status from `running` → `paused`
- New user assignments are blocked
- Existing assignments remain valid

```bash
# Pause a running experiment
curl -X PATCH http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "paused"}'
```

---

## 6. RESUME EXPERIMENT

**Endpoint:** `PATCH /experiments/{id}`

**What happens:**
- Changes status from `paused` → `running`
- User assignments can resume

```bash
# Resume a paused experiment
curl -X PATCH http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "running"}'
```

---

## 7. COMPLETE EXPERIMENT

**Endpoint:** `PATCH /experiments/{id}`

**What happens:**
- Changes status to `completed` (terminal state)
- Sets `ended_at` timestamp
- No more assignments possible
- Results are still accessible

```bash
# Complete an experiment (end it permanently)
curl -X PATCH http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'
```

**Response:** Experiment with `status: completed` and `ended_at` timestamp

---

## 8. UPDATE EXPERIMENT METADATA

**Endpoint:** `PATCH /experiments/{id}`

**What happens:**
- Updates name and/or description
- Does not affect status or variants

```bash
# Update experiment name and description
curl -X PATCH http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Homepage Hero Test v2",
    "description": "Updated description with clearer goals"
  }'
```

---

## 9. DELETE EXPERIMENT

**Endpoint:** `DELETE /experiments/{id}`

**What happens:**
- Permanently deletes experiment
- **Only works for `draft` experiments**
- Cascades: deletes all variants and assignments
- Returns 400 if experiment is running/completed

```bash
# Delete a draft experiment
curl -X DELETE http://localhost:8000/experiments/1 \
  -H "Authorization: Bearer $TOKEN"
```

**Response:** 204 No Content (success) or 400 Bad Request (if not draft)

---

## 10. GET USER ASSIGNMENT

**Endpoint:** `GET /experiments/{id}/assignment/{user_id}`

**What happens:**
- **If user not assigned:** Creates new assignment based on traffic allocation
- **If user already assigned:** Returns existing assignment (IDEMPOTENT)
- Returns variant config for client-side rendering
- Only works on `running` experiments

```bash
# Get/create assignment for user "user-123"
curl -X GET http://localhost:8000/experiments/1/assignment/user-123 \
  -H "Authorization: Bearer $TOKEN"

# Call again - returns SAME variant (idempotency)
curl -X GET http://localhost:8000/experiments/1/assignment/user-123 \
  -H "Authorization: Bearer $TOKEN"
```

**Response:**
```json
{
  "experiment_id": 1,
  "experiment_name": "Homepage Hero Test",
  "user_id": "user-123",
  "variant_id": 2,
  "variant_name": "video_hero",
  "variant_config": {"hero_type": "video", "cta_text": "Get Started"},
  "assigned_at": "2024-01-15T10:30:00",
  "is_new_assignment": true  // false on subsequent calls
}
```

---

## 11. LIST ALL ASSIGNMENTS

**Endpoint:** `GET /experiments/{id}/assignments`

**What happens:**
- Lists all user assignments for an experiment
- Useful for auditing and debugging

```bash
# List all assignments for experiment 1
curl -X GET "http://localhost:8000/experiments/1/assignments" \
  -H "Authorization: Bearer $TOKEN"

# Filter by variant
curl -X GET "http://localhost:8000/experiments/1/assignments?variant_id=2" \
  -H "Authorization: Bearer $TOKEN"

# With pagination
curl -X GET "http://localhost:8000/experiments/1/assignments?limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 12. GET EXPERIMENT RESULTS

**Endpoint:** `GET /experiments/{id}/results`

**What happens:**
- Aggregates all assignments and events
- Calculates conversion rates per variant
- Only counts events AFTER user's assignment time

```bash
# Full results
curl -X GET "http://localhost:8000/experiments/1/results" \
  -H "Authorization: Bearer $TOKEN"

# Summary only (for dashboards)
curl -X GET "http://localhost:8000/experiments/1/results?format=summary" \
  -H "Authorization: Bearer $TOKEN"

# Filter by specific event types
curl -X GET "http://localhost:8000/experiments/1/results?event_types=purchase,signup" \
  -H "Authorization: Bearer $TOKEN"

# With time series data (for charts)
curl -X GET "http://localhost:8000/experiments/1/results?include_time_series=true&time_series_granularity=day" \
  -H "Authorization: Bearer $TOKEN"

# Custom date range
curl -X GET "http://localhost:8000/experiments/1/results?start_date=2024-01-01T00:00:00&end_date=2024-01-31T23:59:59" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Status Transition Diagram

```
┌───────┐     start      ┌─────────┐
│ DRAFT │───────────────▶│ RUNNING │
└───────┘                └────┬────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              ┌──────────┐        ┌───────────┐
              │  PAUSED  │◀──────▶│ COMPLETED │
              └──────────┘ resume └───────────┘
                    │                   ▲
                    └───────────────────┘
                         complete
```










# Assignments Endpoints - Curl Commands

## Setup Token First

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

---

## 1. GET/CREATE USER ASSIGNMENT

**Endpoint:** `GET /experiments/{experiment_id}/assignment/{user_id}`

**What happens:**
- First call → Creates assignment, returns `is_new_assignment: true`
- Subsequent calls → Returns same variant, `is_new_assignment: false`
- Fails with 400 if experiment is not `running`

```bash
# Assign user "alice" to experiment 1
curl -X GET "http://localhost:8000/experiments/1/assignment/alice" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Assign user "bob" to experiment 1
curl -X GET "http://localhost:8000/experiments/1/assignment/bob" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Assign user with UUID format
curl -X GET "http://localhost:8000/experiments/1/assignment/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Assign user with email as ID
curl -X GET "http://localhost:8000/experiments/1/assignment/john.doe@example.com" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Include context (optional metadata stored with assignment)
curl -X GET "http://localhost:8000/experiments/1/assignment/mobile-user-99?context=%7B%22device%22%3A%22iPhone%22%2C%22country%22%3A%22US%22%7D" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 2. VERIFY IDEMPOTENCY

**What happens:**
- Call the same endpoint multiple times
- Always returns the SAME variant
- `is_new_assignment` changes from `true` to `false`

```bash
# First call - creates assignment
echo "=== First Call ==="
curl -s -X GET "http://localhost:8000/experiments/1/assignment/test-user-idempotent" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Second call - returns same assignment
echo "=== Second Call (should be same variant) ==="
curl -s -X GET "http://localhost:8000/experiments/1/assignment/test-user-idempotent" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Third call - still the same
echo "=== Third Call (still same) ==="
curl -s -X GET "http://localhost:8000/experiments/1/assignment/test-user-idempotent" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## 3. LIST ALL ASSIGNMENTS FOR EXPERIMENT

**Endpoint:** `GET /experiments/{experiment_id}/assignments`

**What happens:**
- Returns all users assigned to this experiment
- Shows which variant each user got
- Supports filtering and pagination

```bash
# List all assignments for experiment 1
curl -X GET "http://localhost:8000/experiments/1/assignments" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# List assignments with limit (first 20)
curl -X GET "http://localhost:8000/experiments/1/assignments?limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Paginate (get page 2, 10 per page)
curl -X GET "http://localhost:8000/experiments/1/assignments?limit=10&offset=10" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Filter by specific variant (e.g., variant_id=2)
curl -X GET "http://localhost:8000/experiments/1/assignments?variant_id=2" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Filter by variant with pagination
curl -X GET "http://localhost:8000/experiments/1/assignments?variant_id=1&limit=50&offset=0" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 4. BULK ASSIGN MULTIPLE USERS

**What happens:**
- Simulate assigning many users at once
- Each user gets deterministically assigned based on hash

```bash
# Assign 10 users in a loop
for i in {1..10}; do
  echo "Assigning user-$i..."
  curl -s -X GET "http://localhost:8000/experiments/1/assignment/bulk-user-$i" \
    -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  → {d[\"variant_name\"]}')"
done
```

---

## 5. ERROR CASES

```bash
# Error: Experiment not found (404)
curl -X GET "http://localhost:8000/experiments/99999/assignment/user1" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
# Error: Experiment not running (400) - if experiment is in draft/paused/completed
curl -X GET "http://localhost:8000/experiments/1/assignment/user1" \
  -H "Authorization: Bearer $TOKEN"
# Response: {"detail": "Experiment is not running (status: draft). New assignments cannot be created."}
```

```bash
# Error: Missing auth token (403)
curl -X GET "http://localhost:8000/experiments/1/assignment/user1"
# Response: {"detail": "Not authenticated"}
```

---

## Response Examples

**Successful Assignment:**
```json
{
  "experiment_id": 1,
  "experiment_name": "Button Color Test",
  "user_id": "alice",
  "variant_id": 2,
  "variant_name": "treatment",
  "variant_config": {"color": "green"},
  "assigned_at": "2024-01-15T10:30:00",
  "is_new_assignment": true
}
```

**Returning Existing Assignment:**
```json
{
  "experiment_id": 1,
  "experiment_name": "Button Color Test", 
  "user_id": "alice",
  "variant_id": 2,
  "variant_name": "treatment",
  "variant_config": {"color": "green"},
  "assigned_at": "2024-01-15T10:30:00",
  "is_new_assignment": false
}
```