from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_hello():
    resp = client.get("/api/hello")
    assert resp.status_code == 200
    assert "message" in resp.json()


def test_visits_without_db_returns_503(monkeypatch):
    monkeypatch.delenv("DB_HOST", raising=False)
    assert client.get("/api/visits").status_code == 503


def test_boom_returns_500():
    assert client.get("/api/boom").status_code == 500
