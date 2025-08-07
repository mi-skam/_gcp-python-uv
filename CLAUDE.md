# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flask application with uv dependency management designed for containerized deployment to Google Cloud Run. The project uses `just` for task automation and Docker for containerization.

## Key Commands

### Development
```bash
just install          # Install/update dependencies with uv
just dev              # Run Docker container locally on port 8082
just dev 8083         # Run on alternative port if 8082 is busy
just build            # Build Docker image locally
```

### Deployment
```bash
just check-auth       # Verify gcloud authentication before deploying
just deploy           # Deploy to Cloud Run with public access
just deploy-secure    # Deploy with authentication required
just teardown         # Delete Cloud Run service to avoid costs
```

### Debugging Deployments
```bash
# Check Cloud Run logs if deployment fails
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=gcp-python-uv" --limit=20

# Test locally with exact Docker setup
docker build --platform linux/amd64 -t test . && docker run -p 8080:8080 -e PORT=8080 test
```

## Architecture

### Configuration Variables (justfile)
- `project_id`: Dynamically reads from gcloud config
- `region`: europe-west3 (hardcoded)
- `artifact_registry_repo`: cloud-run-apps
- `service_name`: gcp-python-uv
- `port`: 8080

### Docker Build Considerations
- **MUST use `--platform linux/amd64`** for Cloud Run deployments (prevents exec format errors)
- Dockerfile uses multi-stage approach with uv for fast dependency installation
- Runs as non-root user (appuser) for security
- Uses gunicorn with environment variable PORT expansion via shell

### Flask Application Structure
- `main.py`: Single file Flask app with three endpoints
  - `/` - Returns JSON with timestamp and Python version
  - `/health` - Health check endpoint
  - `/echo/<text>` - Echo service for testing
- Reads PORT from environment variable (defaults to 8080)
- Binds to 0.0.0.0 for container compatibility

### Dependency Management
- Uses `uv` for fast Python dependency management
- Dependencies locked in `uv.lock`
- Python 3.12+ required
- Core dependencies: Flask and Gunicorn

## Common Issues and Solutions

### Platform Architecture Mismatch
If Cloud Run shows "exec format error", ensure Docker builds with `--platform linux/amd64`. The justfile already handles this.

### Authentication Failures
The `deploy` command runs `check-auth` first to verify:
1. Active gcloud authentication
2. Project has billing enabled
3. Correct project is selected

### Port Binding Issues
- Local development uses port mapping (8082:8080 by default)
- Cloud Run requires PORT environment variable
- Gunicorn command uses shell expansion for $PORT

### Artifact Registry Setup
The justfile automatically:
1. Creates the repository if it doesn't exist
2. Configures Docker authentication
3. Uses consistent naming: `{{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}`

## Testing Changes

When modifying the application:
1. Test locally first: `just dev`
2. Verify Docker build: `just build`
3. Check authentication: `just check-auth`
4. Deploy to test: `just deploy`
5. Clean up after testing: `just teardown`

## Security Notes
- `.dockerignore` excludes sensitive files from Docker context
- `deploy-secure` option available for authenticated-only access
- Non-root container user (appuser)
- No secrets in code - uses environment variables