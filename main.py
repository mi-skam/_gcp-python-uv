# app.py
from flask import Flask, jsonify
from datetime import datetime
import os
import sys

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        "message": "Hello from Cloud Run!",
        "python_version": sys.version,
        "timestamp": datetime.now().isoformat(),
        "deployed_with": "uv + Docker"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/echo/<text>')
def echo(text):
    return jsonify({
        "you_said": text,
        "reversed": text[::-1],
        "length": len(text)
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)