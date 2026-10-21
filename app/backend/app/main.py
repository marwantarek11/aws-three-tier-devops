"""Minimal three-tier demo API: health check, a static endpoint and a DB-backed counter."""

import logging
import os

import psycopg
from fastapi import FastAPI, HTTPException

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("api")

app = FastAPI(title="three-tier-api", version=os.getenv("APP_VERSION", "dev"))


def _conninfo() -> str:
    return psycopg.conninfo.make_conninfo(
        host=os.environ["DB_HOST"],
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "app"),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        sslmode=os.getenv("DB_SSLMODE", "prefer"),
        connect_timeout=5,
    )


@app.get("/health")
def health() -> dict:
    # Liveness only: must not depend on the database so a DB blip doesn't kill every task.
    return {"status": "ok"}


@app.get("/api/hello")
def hello() -> dict:
    return {"message": "Hello from the backend API", "version": app.version}


@app.post("/api/visits")
@app.get("/api/visits")
def visits() -> dict:
    try:
        with psycopg.connect(_conninfo()) as conn:
            conn.execute("CREATE TABLE IF NOT EXISTS visits (id SERIAL PRIMARY KEY, ts TIMESTAMPTZ DEFAULT now())")
            conn.execute("INSERT INTO visits DEFAULT VALUES")
            (count,) = conn.execute("SELECT count(*) FROM visits").fetchone()
    except (psycopg.Error, KeyError) as exc:
        log.error("database error: %s", exc)
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"visits": count}


@app.get("/api/boom")
def boom() -> None:
    # Deliberate 500 used to demo the ALB 5xx CloudWatch alarm.
    log.error("boom endpoint called, returning 500")
    raise HTTPException(status_code=500, detail="intentional error for alarm demo")
