# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flask application with uv dependency management designed for containerized deployment to Google Cloud Run. The project uses `just` for task automation, Docker Compose for development, and supports multiple Python versions through `.python-version`.

## Environment Setup

1. **Copy the environment template**: `cp .env.example .env`
2. **Configure your settings** in `.env` (required for all commands)
3. **Python version** is controlled by `.python-version` file (currently 3.12)

## Key Commands

### Development
```bash
just dev [port]       # Start development server with Docker Compose watch mode (default: 8082)
just test-prod [port] # Test production build locally
just update           # Update dependencies using dockerized uv
```

### Build & Deploy
```bash
just build [platform] # Build Docker image (defaults to host platform)
just deploy           # Deploy to Cloud Run (forces linux/amd64)
just destroy          # Delete Cloud Run service to avoid costs
just status           # Check deployment status
just logs [limit]     # View Cloud Run logs (default: 50)
```

### Maintenance
```bash
just clean            # Clean up Docker images
```

## Architecture

### Configuration Management
All configuration is managed through environment variables in `.env`:
- **GCP_PROJECT_ID**: Defaults to current gcloud project
- **GCP_REGION**: Deployment region (europe-west3)
- **SERVICE_NAME**: Cloud Run service name (gcp-python-uv)
- **PORT**: Application port (8080)
- **DEV_LOCAL_PORT**: Local development port (8082)
- **PYTHON_IMAGE**: Auto-derived from `.python-version`

### Python Version Management
- **Single source of truth**: `.python-version` file
- **Automatic image derivation**: `python:X.Y-slim`
- **Tested versions**: 3.9, 3.11, 3.12
- **Change version**: `echo "3.13" > .python-version`

### Docker Build Strategy
- **Platform flexibility**: 
  - `just build` - Uses host platform (fast local builds)
  - `just build linux/amd64` - For x86_64 servers
  - `just deploy` - Always uses linux/amd64 for Cloud Run
- **Multi-stage builds** with uv for fast dependency installation
- **Security**: Runs as non-root user (appuser)

### Development Workflow
- **Docker Compose with watch mode**: Auto-syncs file changes
- **No local dependencies**: Everything runs in containers
- **Dockerized uv**: No need for local uv installation

### Flask Application
- `main.py`: Simple Flask app with three endpoints
  - `/` - Returns JSON with timestamp and Python version
  - `/health` - Health check endpoint
  - `/echo/<text>` - Echo service for testing
- Configurable via environment variables
- Production-ready with Gunicorn

## Common Issues and Solutions

### Missing Environment Variables
```bash
error: environment variable `VARIABLE_NAME` not present
```
**Solution**: Ensure `.env` file exists with all required variables

### Platform Architecture Mismatch
```
exec format error on Cloud Run
```
**Solution**: Deploy command automatically uses `--platform linux/amd64`

### Port Already in Use
```bash
just dev 8083  # Use alternative port
```

### Authentication Issues
```bash
gcloud auth login           # Authenticate with Google Cloud
gcloud config set project PROJECT_ID  # Set default project
```

## Testing Python Version Changes

1. **Change Python version**:
   ```bash
   echo "3.11" > .python-version
   ```

2. **Build and test locally**:
   ```bash
   just build
   just test-prod
   ```

3. **Deploy to Cloud Run**:
   ```bash
   just deploy
   ```

4. **Verify deployment**:
   ```bash
   just status
   curl $(just status | grep URL | cut -d' ' -f3)
   ```

## Best Practices

1. **Always use `.env`**: No hardcoded defaults in justfile
2. **Test locally first**: Use `just dev` for development
3. **Clean up resources**: Run `just destroy` when done testing
4. **Monitor costs**: Cloud Run charges for running services
5. **Version control**: `.env` is gitignored, `.env.example` is tracked

## Security Notes

- `.env` file is gitignored (never commit secrets)
- Docker containers run as non-root user
- Cloud Run deployments use `--allow-unauthenticated` by default
- All secrets should be environment variables

## Project Structure

```
.
├── .env.example        # Environment template (tracked)
├── .env               # Local configuration (gitignored)
├── .python-version    # Python version specification
├── compose.yml        # Docker Compose configuration
├── Dockerfile         # Multi-stage build with uv
├── justfile          # Task automation
├── main.py           # Flask application
├── pyproject.toml    # Python dependencies
└── uv.lock          # Locked dependencies
```

## Design Patterns Used

- **Template Method**: Private recipes in justfile (`_validate-deployment`)
- **Factory Pattern**: `_build-and-push` creates standardized images
- **Singleton Pattern**: `_setup-registry` ensures single repository
- **Configuration as Code**: All settings in `.env`
- **Single Source of Truth**: `.python-version` for Python version