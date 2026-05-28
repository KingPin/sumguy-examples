from flask import Flask, jsonify
import time, random

app = Flask(__name__)

@app.route("/")
def index():
    # Simulate variable latency so you have something interesting to alert on
    time.sleep(random.uniform(0.01, 0.5))
    return jsonify({"status": "ok"})

@app.route("/slow")
def slow():
    time.sleep(random.uniform(0.8, 2.5))
    return jsonify({"status": "done, eventually"})

@app.route("/error")
def error():
    raise ValueError("This error is intentional. Probably.")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
