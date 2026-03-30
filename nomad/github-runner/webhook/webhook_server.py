import hashlib
import hmac
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

import requests

# Configuration from environment
GITHUB_SECRET = os.environ["GITHUB_WEBHOOK_SECRET"]  # Webhook secret from GitHub
GITHUB_PAT = os.environ["GITHUB_PAT"]  # GitHub PAT with repo admin scope
GITHUB_ORG = os.environ["GITHUB_ORG"]  # GitHub organization or username
GITHUB_REPO = os.environ["GITHUB_REPO"]  # GitHub repository name
NOMAD_JOB_TEMPLATE = os.environ["NOMAD_JOB_TEMPLATE"]  # Nomad job template name


def fetch_registration_token():
    url = f"https://api.github.com/repos/{GITHUB_ORG}/{GITHUB_REPO}/actions/runners/registration-token"

    headers = {
        "Authorization": f"token {GITHUB_PAT}",
        "Accept": "application/vnd.github+json",
    }
    print(f"Requesting token from GitHub at {url}")
    response = requests.post(url, headers=headers)
    print("GitHub API response:", response.status_code, response.text)
    response.raise_for_status()
    return response.json()["token"]


def trigger_runner_job(token: str):
    github_url = f"https://github.com/{GITHUB_ORG}/{GITHUB_REPO}"

    cmd = [
        "nomad",
        "job",
        "dispatch",
        "-meta",
        f"github_url={github_url}",
        "-meta",
        f"runner_token={token}",
        "-meta",
        "runner_labels=nomad",
        NOMAD_JOB_TEMPLATE,
    ]
    print("Running Nomad job with command:", " ".join(cmd))
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("Nomad job dispatched successfully:", result.stdout)
    except subprocess.CalledProcessError as e:
        print("Nomad job failed:", e.stderr)
        raise


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers["Content-Length"])
        payload = self.rfile.read(length)

        # Verify GitHub signature
        signature = self.headers.get("X-Hub-Signature-256")
        if not signature:
            print("Missing signature header")
            self.send_response(403)
            self.end_headers()
            return

        digest = hmac.new(GITHUB_SECRET.encode(), payload, hashlib.sha256).hexdigest()
        expected = f"sha256={digest}"
        if not hmac.compare_digest(signature, expected):
            print("Signature mismatch")
            self.send_response(403)
            self.end_headers()
            return

        event = self.headers.get("X-GitHub-Event")
        if event != "workflow_job":
            print(f"Ignoring event type: {event}")
            self.send_response(200)
            self.end_headers()
            return

        body = json.loads(payload)
        action = body.get("action")
        labels = [l.lower() for l in body["workflow_job"].get("labels", [])]

        print(f"Received workflow_job event: action={action}, labels={labels}")

        # Only react to queued jobs that match desired label
        if action == "queued" and "nomad" in labels:
            try:
                token = fetch_registration_token()
                trigger_runner_job(token)
                print("Runner job dispatched successfully")
                self.send_response(202)
            except Exception as e:
                print(f"Error launching runner job: {e}")
                self.send_response(500)
        else:
            self.send_response(200)

        self.end_headers()

    def do_GET(self):
        # Health check endpoint
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        else:
            self.send_response(404)
            self.end_headers()


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    server = HTTPServer(("", port), WebhookHandler)
    print(f"Webhook server listening on port {port}...")
    server.serve_forever()
