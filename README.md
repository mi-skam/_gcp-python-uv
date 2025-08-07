# gcp-python-uv

Flask application template for Google Cloud Run deployment using Docker, uv package management, and just for task automation.

## Prerequisites

- Docker
- [just](https://github.com/casey/just)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) - For Cloud Run deployment
- [jq](https://jqlang.github.io/jq/) - For log formatting (optional)

Note: No local Python or uv installation required.

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd gcp-python-uv

# Set up environment
cp .env.example .env
# Edit .env with your settings (all fields required)
```

### 2. Local Development

```bash
# Start development server (http://localhost:8082)
just dev

# Or use a different port
just dev 3000
```

### 3. Deploy to Cloud Run

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Deploy
just deploy

# Check deployment
just status
```

### 4. Clean Up

```bash
# Remove Cloud Run service (stop billing)
just destroy

# Clean local Docker images
just clean
```

## Available Commands

### Development
| Command | Description |
|---------|-------------|
| `just dev [port]` | Start dev server with live reload (default: 8082) |
| `just test-prod [port]` | Test production build locally |
| `just update` | Update Python dependencies |

### Build & Deploy
| Command | Description |
|---------|-------------|
| `just build [platform]` | Build Docker image (optional platform) |
| `just deploy` | Deploy to Google Cloud Run |
| `just destroy` | Delete Cloud Run service |
| `just status` | Show deployment status and URL |
| `just logs [limit]` | View service logs (default: 50) |
| `just clean` | Remove local Docker images |

## Configuration

### Environment Variables

All configuration is managed through the `.env` file:

```bash
# Google Cloud Configuration
GCP_PROJECT_ID=your-project-id       # Required (or use gcloud default)
GCP_REGION=europe-west3              # Required
ARTIFACT_REGISTRY_REPO=cloud-run-apps # Required
SERVICE_NAME=gcp-python-uv           # Required

# Application Configuration
PORT=8080                            # Required
DEV_LOCAL_PORT=8082                  # Required
FLASK_DEBUG=true                     # For development

# Docker Configuration (optional)
# PYTHON_IMAGE=python:3.12-slim      # Auto-derived from .python-version
```

### Python Version Management

Python version is controlled by `.python-version` file:

```bash
# Check current version
cat .python-version

# Change to Python 3.11
echo "3.11" > .python-version
just build
just deploy

# Change to Python 3.13
echo "3.13" > .python-version
```

The system automatically:
- Derives the Docker image (`python:X.Y-slim`)
- Manages version-specific dependencies
- Ensures consistency across all environments

## Development Workflow

### Local Development

```bash
just dev
```

Uses Docker Compose with watch mode for automatic file syncing and live reload.

### Testing Production Build

```bash
just build           # Build container
just test-prod       # Run production container locally
```

### Deployment Workflow

```bash
just build linux/amd64  # Build for Cloud Run (optional, deploy does this)
just deploy            # Deploy to Cloud Run
just status           # Get service URL
just logs            # View logs
just destroy         # Clean up when done
```

## Platform Build Strategy

The project intelligently handles different platforms:

| Command | Platform | Use Case |
|---------|----------|----------|
| `just build` | Host platform | Fast local development |
| `just build linux/amd64` | x86_64 | Cloud Run, most servers |
| `just build linux/arm64` | ARM64 | ARM servers, some Macs |
| `just deploy` | Always linux/amd64 | Cloud Run requirement |

## API Endpoints

The Flask application provides:

- `GET /` - Returns system info and timestamp
- `GET /health` - Health check endpoint
- `GET /echo/<text>` - Echo service for testing

Example response from `/`:
```json
{
  "message": "Hello from Cloud Run!",
  "python_version": "3.12.0 (main, ...)",
  "timestamp": "2024-01-01T12:00:00.000000",
  "deployed_with": "uv + Docker"
}
```

## Troubleshooting

### Missing Environment Variables
```
error: environment variable `VARIABLE_NAME` not present
```
Solution: Ensure `.env` file exists with all required variables

### Port Already in Use
```bash
just dev 8083  # Use alternative port
```

### Authentication Issues
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Platform Mismatch on Cloud Run
The deployment automatically uses `linux/amd64` platform

### View Cloud Run Service in Console
```
https://console.cloud.google.com/run?project=YOUR_PROJECT_ID
```

## License

MIT

## Support

For issues or questions:
- Review troubleshooting section above
- Open an issue on GitHub
