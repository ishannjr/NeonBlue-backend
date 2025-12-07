# Experimentation API

A RESTful A/B testing API service for managing experiments, assigning users to variants, recording events, and analyzing experiment performance.

---

## Deployed (Backend and Frontend)

| Service | URL |
|---------|-----|
| **Backend API** | [ec2-3-136-108-183.us-east-2.compute.amazonaws.com:8000](http://ec2-3-136-108-183.us-east-2.compute.amazonaws.com:8000) |
| **API Docs (Swagger)** | [ec2-3-136-108-183.us-east-2.compute.amazonaws.com:8000/docs](http://ec2-3-136-108-183.us-east-2.compute.amazonaws.com:8000/docs) |
| **Frontend Dashboard** | [neon-blue-frontend.vercel.app](https://neon-blue-frontend.vercel.app/) |

**To use the frontend:**
1. Get a JWT token from `POST /auth/token` with `{"username": "admin", "password": "admin123"}`
2. Enter the token in the frontend to view experiment analytics

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[DOCUMENTATION.md](./DOCUMENTATION.md)** | Architecture decisions, trade-offs, and scaling considerations |
| **[endpointUsage.md](./endpointUsage.md)** | API endpoints with curl examples and demo script |

---

## Quick Start

### Option 1: Docker (Recommended)

```bash
# Build and run
docker-compose up --build

# Would be running at http://localhost:8000
# Documentation would be available at http://localhost:8000/docs
```

### Option 2: Local Development

```bash
python -m venv venv
source venv/bin/activate  

pip install -r requirements.txt

uvicorn app.main:app --reload

```

## API Endpoints & Usage

For complete API documentation with curl examples, see **[endpointUsage.md](./endpointUsage.md)**

### Quick Reference

| Category | Endpoints |
|----------|-----------|
| **Auth** | `POST /auth/token`, `POST /auth/register` |
| **Experiments** | `POST /experiments`, `GET /experiments/{id}`, `PATCH /experiments/{id}` |
| **Assignments** | `GET /experiments/{id}/assignment/{user_id}` |
| **Events** | `POST /events`, `POST /events/batch` |
| **Results** | `GET /experiments/{id}/results` |



## Environment Configuration

Create a `.env` file in the project root:

```bash
JWT_SECRET_KEY=your-secret-key-generate-with-openssl-rand-hex-32
DATABASE_URL=sqlite:///./experimentation.db
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=60
LOG_LEVEL=INFO
API_TITLE=Experimentation API
API_VERSION=1.0.0
```

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET_KEY` | **(required)** | Secret key for signing JWT tokens |
| `JWT_ALGORITHM` | `HS256` | JWT signing algorithm |
| `JWT_EXPIRATION_MINUTES` | `60` | Token expiration in minutes |
| `DATABASE_URL` | `sqlite:///./experimentation.db` | Database connection string |
| `LOG_LEVEL` | `INFO` | Logging level |
| `API_TITLE` | `Experimentation API` | API title for docs |
| `API_VERSION` | `1.0.0` | API version |

Generate a secure secret key:
```bash
openssl rand -hex 32
```

## Interactive Documentation

When the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc



