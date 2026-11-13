# Shop model

Predicts whether an item in the shop will sell, from its price.

## Requirements

Python 3.12 with the venv module. On Ubuntu:

```bash
sudo apt install python3 python3-venv
```
## Install

Run these from this folder, the one with pyproject.toml:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 -m pip install -e ".[dev]"
cp env.example .env
```

## Test

```bash
pytest
```

## The pipeline

Run these targets with `make` from the project folder, with the virtual
environment activated:

| Target | What it does |
| --- | --- |
| `make install` | Installs the requirements and the project in editable mode with development dependencies. |
| `make lint` | Runs Ruff checks on `src` and `tests`. |
| `make test` | Runs the test suite with `pytest -q`. |
| `make validate` | Runs `shop-validate` to check the input data. |
| `make gate` | Runs `shop-gate` to score the model and check the minimum accuracy, using the `holdout` split by default. Override it with `make gate GATE_SPLIT=<split>`. |
| `make build` | Builds the Docker image, passes the project version as `MODEL_VERSION`, and tags the image with both the version and the version plus Git commit. The image name defaults to `shop-model`; override it with `IMAGE=<name>`. |
| `make up` | Builds and starts the Docker Compose services in the background, setting `MODEL_VERSION` to the project version. |
| `make version` | Prints the project version from `pyproject.toml`. |
| `make ci` | Runs `lint`, `test`, `validate`, `gate` and `build` in order, stopping at the first failure. |

## Train

```bash
shop-train
```
The model is saved to models/model.joblib. Shared settings are in
config/config.yaml; settings for your machine go in .env.

## FastAPI

From the project folder, with the virtual environment activated, start the API server:

```bash
uvicorn shop_model.api:app --port 8888
```

Keep this terminal running. Use a second terminal on the same machine for the requests below.

The API provides two endpoints:

### GET /health

Checks that the service is running and responding. It returns a response such as `{"status": "ok"}`.

```bash
curl http://localhost:8888/health
```

### POST /predict

Accepts a price as JSON, runs the model and returns its prediction. FastAPI validates the input before the prediction function runs.

```bash
curl -X POST http://localhost:8888/predict \
  -H "Content-Type: application/json" \
  -d '{"price": 20}'
```

### Interactive documentation

Open [the interactive API documentation](http://localhost:8888/docs) in a browser on the server machine to explore and test the endpoints.

Connects a POST request to a function that receives input, such as {"price": 20}; this runs the model and returns its prediction. Which could be called like this:

```bash
curl -X POST localhost:8888/predict -H "Content-Type: application/json" -d '{"price": 20}'
```

## Run the API with Docker

Run these commands in Lubuntu, from the project's top-level folder.

### Build the image

```bash
docker build --progress=plain -t shop-model:0.1 .
```

This installs the dependencies, packages the application and trains the model.

### Start the container

```bash
docker run -d --name shop-api -p 8888:8888 shop-model:0.1
```

The API runs in the background. Port 8888 on Lubuntu forwards requests to port 8888 inside the container.

### Check the API

Confirm that the container is running:

```bash
docker ps
```

Check the health endpoint:

```bash
curl http://localhost:8888/health
```

Expected response:

```json
{"status":"ok"}
```

Request a prediction:

```bash
curl -X POST http://localhost:8888/predict \
  -H "Content-Type: application/json" \
  -d '{"price": 20}'
```

The response contains the submitted price and its predicted probability of being sold.

### View logs and stop the container

```bash
docker logs shop-api
docker stop shop-api
```

To start the same stopped container again:

```bash
docker start shop-api
```

## Run the API and database with Docker Compose

From the `shop-model` folder (the one containing `compose.yaml`), make sure
`.env` contains `DB_PASSWORD`. If you have not created `.env` yet, copy
`env.example` to `.env` and set the password there.

If the standalone `shop-api` container is running, stop it first with
`docker stop shop-api` to free port 8888.

Build and start both services in the background:

```bash
docker compose up -d --build
docker compose ps
```

Compose starts PostgreSQL (`db`) and waits for it to be healthy before starting
the API (`api`). The image build also trains the model.

### Store and check predictions

Check the API and submit a prediction:

```bash
curl http://localhost:8888/health
curl -X POST http://localhost:8888/predict \
  -H "Content-Type: application/json" \
  -d '{"price": 20}'
```

Each prediction is stored in PostgreSQL with its price, probability, model
version and creation time. Query the latest 10 predictions directly through
the database service:

```bash
docker compose exec db psql -U shop -d shop -c \
  "SELECT id, created_at, price, probability, model_version FROM predictions ORDER BY id DESC LIMIT 10;"
```

The stored `probability` has full precision; the API response rounds
`probability_sold` to three decimal places. If a prediction is returned but no
row appears, check the API logs for a database error:

```bash
docker compose logs api db
```

### Open the dashboard and generate traffic

The same `docker compose up -d --build` command also starts Prometheus and
Grafana. Open the [Model Service dashboard](http://localhost:3000/d/adzvx28)
in a browser on the machine running Docker. Grafana opens without a login.
The dashboard refreshes every five seconds and shows request rate, prediction
latency and the distribution of input prices.

From the project folder, run the traffic generator in a second terminal:

```bash
python3 monitoring/traffic.py --field price --mean 23 --sd 12 --rate 5 --duration 120
```

This sends about five prediction requests per second for two minutes to
`http://localhost:8888/predict`. It uses only the Python standard library, so
no virtual environment is needed. Requests also create prediction rows in the
database. Allow a few scrapes for the dashboard panels to fill with data.

To see how a change in input prices affects the dashboard, run another batch
with a higher mean:

```bash
python3 monitoring/traffic.py --field price --mean 35 --sd 12 --rate 5 --duration 120
```

Use `--rate` to change the requests per second and `--duration` to change the
run time in seconds, or press `Ctrl+C` to stop early. If requests fail, check
`curl http://localhost:8888/health` and `docker compose logs api prometheus grafana`.
Prometheus is also available at [http://localhost:9090](http://localhost:9090).

### Stop the services

```bash
docker compose down
```

Predictions remain in the `db-data` volume and are available when you run
`docker compose up -d` again. `docker compose down -v` also deletes that volume
and its stored predictions. The schema in `db/init.sql` runs only when the
database is first created.
