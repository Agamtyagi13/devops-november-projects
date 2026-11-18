import os, random, time
from flask import Flask, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)
VERSION = os.getenv("APP_VERSION", "v1")
ERROR_RATE = float(os.getenv("ERROR_RATE", "0"))     # simulate a bad release: ERROR_RATE=0.5
LATENCY_MS = int(os.getenv("LATENCY_MS", "0"))

REQS = Counter("http_requests_total", "Requests", ["status", "version"])
LAT = Histogram("http_request_duration_seconds", "Latency", ["version"])

@app.route("/")
def index():
    with LAT.labels(VERSION).time():
        time.sleep(LATENCY_MS / 1000)
        if random.random() < ERROR_RATE:
            REQS.labels("500", VERSION).inc()
            return {"version": VERSION, "ok": False}, 500
        REQS.labels("200", VERSION).inc()
        return {"version": VERSION, "ok": True}

@app.route("/healthz")
def health():
    return "ok"

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
