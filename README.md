# gcp-python-uv

[![CI](https://github.com/mi-skam/_gcp-python-uv/actions/workflows/ci.yml/badge.svg)](https://github.com/mi-skam/_gcp-python-uv/actions/workflows/ci.yml)
[![Release and Deploy](https://github.com/mi-skam/_gcp-python-uv/actions/workflows/release.yml/badge.svg)](https://github.com/mi-skam/_gcp-python-uv/actions/workflows/release.yml)

Flask application template for Google Cloud Run deployment using Docker, uv package management, and just for task automation.

**🚀 Zero Configuration Required** - Clone and run `just dev` to get started immediately!

## Prerequisites

- Docker
- [just](https://github.com/casey/just)

**For Cloud Run deployment (optional):**
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [jq](https://jqlang.github.io/jq/) - For log formatting

Note: No local Python or uv installation required.

## Quick Start

### 1. Start Development (Zero Configuration)

```bash
# Clone the repository
git clone <repository-url>
cd gcp-python-uv

# Start development server immediately (http://localhost:8082)
just dev
```

**That's it!** The project uses sensible defaults and requires no configuration for local development.

### 2. Deploy to Cloud Run (Optional)

```bash
# One-time setup: authenticate and set project
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Deploy with zero configuration
just deploy

# Check deployment
just status
```

### 3. Clean Up

```bash
# Remove Cloud Run service (stop billing)
just destroy
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

## Configuration (Optional)

The project works with zero configuration using these defaults:

- **Region**: `europe-west3`
- **Service Name**: `gcp-python-uv`
- **Ports**: `8080` (production), `8082` (development)
- **Registry**: `cloud-run-apps`
- **Project**: Uses your current `gcloud` project

**To customize**: Copy `.env.example` to `.env` and modify any values.

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

## CI/CD and Automated Deployment

This repository includes GitHub Actions workflows for automated testing and deployment:

### 🚀 Automated Release Workflow

When you push a version tag (`v*`), the system automatically:
1. Builds and tests the Docker image
2. Pushes to Google Artifact Registry
3. Deploys to Cloud Run with the version tag
4. Creates a GitHub release with deployment info

```bash
# Create and push a new release
git tag v0.2.0
git push origin v0.2.0
```

### 🧪 Continuous Integration

Pull requests and main branch pushes trigger:
- Multi-version Python testing (3.9, 3.11, 3.12)
- Docker build verification
- Flask application health checks

### 📋 CI/CD Setup

To enable automated deployments, see [`.github/SETUP.md`](./.github/SETUP.md) for:
- Google Cloud service account creation
- GitHub repository secrets configuration
- Artifact Registry setup
- Monitoring and cost management

### 🏷️ Release Management

The system supports semantic versioning:
- `v1.0.0` - Major releases
- `v1.1.0` - Minor features
- `v1.1.1` - Patches and fixes

Each release creates a permanent deployment with version tracking.

## License

MIT

## Support

For issues or questions:
- Review troubleshooting section above
- Check [CI/CD Setup Guide](./.github/SETUP.md) for deployment issues
- Open an issue on GitHub
