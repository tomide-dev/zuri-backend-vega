# Zuri Market — Backend

## Architecture Diagram
![Architecture Diagram](https://github.com/tomide-dev/zuri-backend-vega/blob/main/Architecture%20Diagram.png)

## 1. Project Overview

This is the REST API powering the Zuri Market ecommerce platform. It serves the product catalog, exposes store configuration, and validates shopping cart contents (stock checks and pricing) before checkout. Built with Node.js and Express, with an in-memory product dataset.

## 2. Tech Stack

- **Node.js** 20
- **Express** ^4.19.2 — HTTP server and routing
- **cors** ^2.8.5 — Cross-origin request support, so the frontend (running on a different host/port) can call the API
- **dotenv** ^16.4.5 — Loads environment variables from a `.env` file in development
- **nodemon** ^3.1.4 (dev dependency) — Auto-restarts the server on file changes during local development

## 3. Project Structure

```
.
├── data/
│   └── products.js        # In-memory product catalog (id, name, category, price, stock, etc.)
├── k8s/
│   └── backend-deployment.yaml     # Kubernetes Deployment + NodePort Service
    └── backend-service.yaml 
    └── namespace.yaml              # workspace inside kubernetes
├── .github/workflows/
│   └── backend-ci-cd.yml          # CI/CD: test, audit, scan, build, push, deploy
├── server.js                # Express app: middleware, routes, server startup
├── Dockerfile                # Container build definition
├── package.json
└── .env.example               # Template listing required environment variables
```

- **`server.js`** — The entire application. Sets up Express, CORS, JSON body parsing, an API-key middleware for protected routes, and all route handlers.
- **`data/products.js`** — A hardcoded array of product objects exported as the "database" for this demo API. No external database is used.
- **`Dockerfile`** — Builds a production image on `node:18-alpine`.
- **`k8s/backend-deployment.yaml`** — Describes how the app runs in Kubernetes, including how `API_SECRET_KEY` and `STORE_NAME` are injected from a cluster Secret.
- **`.github/workflows/backend-ci-cd.yml`** — The pipeline that builds, scans, pushes, and deploys the app on every push to `main`.

## 4. Environment Variables

All variables are listed in `.env.example`. Copy it to `.env` and fill in real values locally — **never commit actual secrets to the README or the repo.**

| Variable | Description | Required? |
|---|---|---|
| `PORT` | Port the Express server listens on | Optional — defaults to `5000` |
| `API_SECRET_KEY` | Shared secret checked against the `x-api-key` header on protected routes (currently `POST /api/cart/validate`) | **Required** — requests to protected routes fail with `401` if unset or mismatched |
| `STORE_NAME` | Display name returned by `GET /api/store` | Optional — defaults to `"My Store"` |

## 5. Running Locally


```bash
# 1. Clone the repo
git clone https://github.com/tomide-dev/zuri-backend-vega.git
cd zuriapp-backend

# 2. Install dependencies
npm install

# 3. Set up environment variables
cp .env.example .env
# then edit .env with your own values
# demo

# 4. Start the server
npm run dev     # with auto-restart (nodemon), recommended for local dev
# or
npm start       # plain node, closer to how it runs in production
```

The API is available at `http://localhost:5000`.

## 6. API Endpoints

| Method | Path | Auth required? | Description |
|---|---|---|---|
| `GET` | `/api/store` | No | Returns store metadata |
| `GET` | `/api/products` | No | Returns all products. Supports an optional `?category=` query param to filter |
| `GET` | `/api/products/:id` | No | Returns a single product by numeric ID, or `404` if not found |
| `POST` | `/api/cart/validate` | **Yes** — `x-api-key` header must match `API_SECRET_KEY` | Validates a cart payload against current stock/pricing and returns a computed total |

### `GET /api/store`

Example response:
```json
{
  "name": "zuri market vega",
  "totalProducts": 8
}
```

### `GET /api/products`

Example response (truncated):
```json
[
  {
    "id": 1,
    "name": "Merino crew neck",
    "category": "apparel",
    "price": 89,
    "stock": 12,
    "badge": null,
    "description": "Lightweight 100% merino wool. Naturally temperature-regulating and itch-free.",
    "image": "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&q=80"
  }
]
```

### `GET /api/products/:id`

Example response:
```json
{
  "id": 2,
  "name": "Ceramic pour-over",
  "category": "home",
  "price": 42,
  "stock": 8,
  "badge": "bestseller",
  "description": "Hand-thrown ceramic dripper. Brews a clean, nuanced cup every time.",
  "image": "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500&q=80"
}
```

If no product matches the ID:
```json
{ "error": "Product not found" }
```

### `POST /api/cart/validate`

Requires header: `x-api-key: <API_SECRET_KEY>`

Request body:
```json
{
  "items": [
    { "id": 1, "quantity": 2 },
    { "id": 99, "quantity": 1 }
  ]
}
```

Example response:
```json
{
  "items": [
    { "id": 1, "valid": true, "name": "Merino crew neck", "price": 89, "quantity": 2, "subtotal": 178 },
    { "id": 99, "valid": false, "reason": "Product not found" }
  ],
  "total": 178
}
```

Without a valid `x-api-key` header:
```json
{ "error": "Unauthorized: invalid or missing API key" }
```

## 7. Docker

Build the image locally:

```bash
docker build -t zurimarket-backend .
```

Run the container:

```bash
docker run -p 5000:5000 zurimarket-backend
```

**Docker Hub image:** `tomidedev/zurimarket-backend`

**Tag convention used by the CI/CD pipeline:** every push to `main` builds and pushes two tags — `tomidedev/zurimarket-backend:<git-sha>` (immutable, traceable to the exact commit) and `tomidedev/zurimarket-backend:latest`. The Kubernetes deployment is then updated to reference the specific `<git-sha>` tag for that release, not `latest`.

## 8. Deployment

The underlying k3s cluster and supporting AWS infrastructure (EC2 instance, IAM roles, Secrets Manager entries, etc.) are provisioned with **Terraform**. 

The provisioning code lives in [Zuri Market - Infrastructure](https://github.com/tomide-dev/zuri-market-vega-infra.git) — refer to it for setup and teardown instructions; this README only covers the application deployment itself.

Deployment is fully automated via **GitHub Actions** (`.github/workflows/backend-ci-cd.yml`) using two jobs. On every push to `main`, the pipeline installs dependencies, runs tests and `npm audit`, builds the Docker image, and if the scan passes it pushes the image to Docker Hub and rolls it out to the **k3s** cluster running on the EC2 Instance.

Edit this file as well as your **Kubernetes Manifests** (`.k8s/backend-deployment.yaml`) to match your configurations

The frontend Service is exposed via Kubernetes NodePort on port 30080, making the app reachable externally at:

`http://<EC2_PUBLIC_IP>:30080`

### Push to your remote GitHub Repo

You now have everything in place. Commit the entire application code to your GitHub repo and push everything to main. This is what triggers the first full deployment.

```bash
git add .
git commit -m "Your_Commit_Message"
git push origin main
```
From this point on, every push to main triggers the full pipeline automatically.

Once the pipeline runs successfully, verify the deployment from your EC2 Instance:

```bash
kubectl get pods -n zurimarket      
# both backend and frontend pods should show Running
kubectl get services   
# confirm frontend-service shows nodePort 30080
# and backend-service shows nodePort 30893
```


## 9. Secrets

Secrets are sourced differently depending on where the app is running:

- **Locally** — secrets come from your own `.env` file (created from `.env.example`), and are never committed to the repo.
- **In the CI/CD pipeline** — secrets used to build, scan, and push the image (e.g. `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `KUBECONFIG_DATA`) are stored as **GitHub Actions Secrets** and injected into the workflow at runtime — they're never hardcoded in the YAML.
- **In production** — the actual application secrets (`API_SECRET_KEY`, `STORE_NAME`) are stored in **AWS Secrets Manager**. The deploy job fetches them at deploy time and syncs them into a Kubernetes `Secret` object (`backend-secrets`), which the pod then consumes as environment variables via `secretKeyRef`. The values never appear in the manifest files or the Git history.

## 10. Final Project Expectation

You should be able to Access the live App at `http://44.213.121.118:30080` as shown below

![Live App](zuri-market-final-deployment-image.PNG)

### Overall Project Recommendation

| Improvement | Why it matters |
|---|---|
| Multi-environment pipeline with dev, staging, and production | All changes currently go directly to production on every push to main. A dev → staging → prod promotion model with environment-scoped GitHub Secrets means changes are validated in a lower environment before reaching real users. |
| Add HTTPS and TLS across all services end to end | All traffic currently travels over plain HTTP between the user and the frontend, and between the frontend and the backend API. HTTPS is non-negotiable for production: it protects data in transit, is required for modern browser APIs, and is expected by users. |
| Deploy a logging, monitoring, and alerting solution (ELK stack, CloudWatch or Prometheus + Grafana) | There is currently no visibility into pod health, API response times, error rates, or resource usage after deployment. Without monitoring you are blind to problems until users report them. CloudWatch or a Prometheus/Grafana stack surfaces issues proactively. |

The recommendations above are not exhaustive but represent a solid foundation for evolving the project into a production-ready solution that adheres to modern DevOps principles, security standards, scalability requirements, and engineering best practices.
---

*Author [Tomide Olubanjo](linkedin.com/in/oluwatomide-olubanjo)*