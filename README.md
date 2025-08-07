# gcp-python-uv

Flask app with uv dependency management, containerized deployment to Google Cloud Run with git-based versioning.

## Prerequisites

- Docker Desktop
- [uv](https://github.com/astral-sh/uv) - `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [just](https://github.com/casey/just) - `brew install just` or `cargo install just`
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) with authenticated account
- Google Cloud project with billing enabled
- [jq](https://jqlang.github.io/jq/) for log formatting

## Quick Start

```bash
# Install dependencies
just update

# Run locally
just dev

# Deploy to Cloud Run (public)
just deploy

# Clean up to avoid costs
just kill
```

## Available Commands

### Development
- `just update` - Install/update dependencies with uv
- `just dev [port]` - Run development server locally (default: 8082)
- `just build` - Build Docker image with git hash tagging

### Deployment
- `just deploy` - Deploy to Cloud Run (public access)
- `just kill` - Delete Cloud Run service to avoid costs
- `just status` - Check service health and URL
- `just logs` - View formatted Cloud Run logs

### Utilities
- `just clean` - Clean up Docker images

## Features

- **Git-based versioning**: Images tagged with commit hash for better tracking
- **Cost optimization**: Easy service deletion with `just kill`
- **Environment validation**: Automatic checks for required tools and authentication
- **Formatted logging**: Human-readable log output with timestamps
- **Platform consistency**: Automatic AMD64 builds for Cloud Run compatibility

## Cost Estimation

For low usage (1-2 users, ~30 requests/month):
- **Cloud Run**: ~$0.15-0.35/month per project
- **Artifact Registry**: ~$0.10/month per project  
- **Total**: ~$1.15-1.75/month for 3 active projects

## Troubleshooting

### "VIRTUAL_ENV warnings"
Run `unset VIRTUAL_ENV` before using uv commands.

### "Not authenticated with gcloud"
Run `gcloud auth login` and select your Google account.

### "Project may not have billing enabled"
Enable billing at https://console.cloud.google.com/billing

### "exec format error" on Cloud Run
The justfile automatically builds for AMD64 - this shouldn't occur.

### Container fails to start on Cloud Run
Check formatted logs: `just logs`

### Port already in use
Change the port: `just dev 8083`

### Clean up old images
```bash
# List all images
gcloud artifacts docker images list europe-west3-docker.pkg.dev/PROJECT_ID/cloud-run-apps

# Delete specific tag
gcloud artifacts docker images delete europe-west3-docker.pkg.dev/PROJECT_ID/cloud-run-apps/gcp-python-uv:TAG
```