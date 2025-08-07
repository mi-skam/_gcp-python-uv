# gcp-python-uv

Flask app with uv dependency management, containerized deployment to Google Cloud Run.

## Prerequisites

- Docker Desktop
- [uv](https://github.com/astral-sh/uv) - `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [just](https://github.com/casey/just) - `brew install just` or `cargo install just`
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) with authenticated account
- Google Cloud project with billing enabled

## Quick Start

```bash
# Install dependencies
just install

# Run locally
just dev

# Deploy to Cloud Run (public)
just deploy

# Or deploy with authentication required
just deploy-secure

# Clean up to avoid costs
just teardown
```

## Available Commands

- `just dev` - Run development server locally
- `just deploy` - Deploy to Cloud Run (public access)
- `just deploy-secure` - Deploy with authentication required
- `just teardown` - Delete Cloud Run service
- `just check-auth` - Verify gcloud authentication
- `just build` - Build Docker image
- `just install` - Install/update dependencies
- `just clean` - Clean Docker images

## Troubleshooting

### "Not authenticated with gcloud"
Run `gcloud auth login` and select your Google account.

### "Project may not have billing enabled"
Enable billing at https://console.cloud.google.com/billing

### "exec format error" on Cloud Run
The Docker image platform doesn't match. The justfile automatically builds for AMD64.

### Container fails to start on Cloud Run
Check logs: `gcloud logging read "resource.type=cloud_run_revision" --limit=20`

### Port already in use
Change the port: `just dev 8083`