# justfile for gcp-python-uv project
project_id := `gcloud config get-value project`
region := "europe-west3"
artifact_registry_repo := "cloud-run-apps"
service_name := "gcp-python-uv"
port := "8080"
git_hash := `git rev-parse --short HEAD`
image_tag := region + "-docker.pkg.dev/" + project_id + "/" + artifact_registry_repo + "/" + service_name + ":" + git_hash

# Default target
default:
    @just --list

# Build the Docker image
build:
    docker build --platform linux/amd64 -t {{service_name}} -t {{image_tag}} .

# Update dependencies with uv
# Note: If you see VIRTUAL_ENV warnings, run: unset VIRTUAL_ENV
update:
    uv sync --upgrade

# Run development server with Docker
dev local_port="8082":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Function to cleanup on exit
    cleanup() {
        echo "Stopping container..."
        docker ps -q --filter ancestor={{service_name}} | xargs -r docker stop
    }
    
    # Set trap to cleanup on SIGINT (Ctrl+C) or EXIT
    trap cleanup SIGINT EXIT
    
    # Run the container
    docker run -p {{local_port}}:{{port}} -e PORT={{port}} --rm {{service_name}}

# Validate required environment variables
_validate-env:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ -z "{{project_id}}" || "{{project_id}}" == "(unset)" ]]; then
        echo "❌ No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        echo "❌ gcloud CLI not found. Install Google Cloud SDK"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found. Install Docker"
        exit 1
    fi
    
    echo "✅ Environment validation passed"

# Check if authenticated with gcloud
_check-auth: _validate-env
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Checking gcloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo "❌ Not authenticated with gcloud. Please run: gcloud auth login"
        exit 1
    fi
    
    echo "✅ Authenticated as: $(gcloud config get-value account)"
    echo "📦 Project: {{project_id}}"
    
    # Check if project has billing
    if ! gcloud billing projects describe {{project_id}} --format="value(billingAccountName)" 2>/dev/null | grep -q .; then
        echo "⚠️  Warning: Project may not have billing enabled"
    fi

# Setup Artifact Registry repository
_setup-registry: _validate-env _check-auth
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Setting up Artifact Registry..."
    # Create Artifact Registry repository if it doesn't exist
    if gcloud artifacts repositories describe {{artifact_registry_repo}} \
        --location={{region}} \
        --project={{project_id}} &>/dev/null; then
        echo "✅ Repository '{{artifact_registry_repo}}' already exists"
    else
        echo "Creating Artifact Registry repository '{{artifact_registry_repo}}'..."
        gcloud artifacts repositories create {{artifact_registry_repo}} \
            --repository-format=docker \
            --location={{region}} \
            --project={{project_id}} \
            --description="Docker images for Cloud Run applications"
        echo "✅ Repository created"
    fi
    
    # Configure Docker authentication
    echo "Configuring Docker authentication..."
    gcloud auth configure-docker {{region}}-docker.pkg.dev --quiet
    echo "✅ Docker authentication configured"

# Deploy to Google Cloud Run (public access)
deploy: _setup-registry _build-push
    echo "🚀 Deploying to Cloud Run..."
    gcloud run deploy {{service_name}} --image {{image_tag}} --platform managed --region {{region}} --allow-unauthenticated --project {{project_id}}

# Delete Cloud Run service to avoid costs
kill:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🗑️  Deleting Cloud Run service..."
    if gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} &>/dev/null; then
        gcloud run services delete {{service_name}} --region {{region}} --project {{project_id}} --quiet
        echo "✅ Service deleted"
    else
        echo "ℹ️  Service not found (may already be deleted)"
    fi

# Build and push Docker image (shared recipe)
_build-push:
    echo "🔨 Building Docker image for Cloud Run (AMD64)..."
    docker build --platform linux/amd64 -t {{image_tag}} .
    echo "📤 Pushing to Artifact Registry..."
    docker push {{image_tag}}

# View Cloud Run service logs
logs:
    gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name={{service_name}}" --limit=50 --project={{project_id}} --format=json | jq -r '.[] | "\(.timestamp)-\(.textPayload // .jsonPayload.message // "No message")"'

# Check service status
status:
    #!/usr/bin/env bash
    set -euo pipefail
    if gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} &>/dev/null; then
        echo "✅ Service is deployed"
        echo "🌐 URL: $(gcloud run services describe {{service_name}} --region={{region}} --format='value(status.url)')"
        echo "📊 Status: $(gcloud run services describe {{service_name}} --region={{region}} --format='value(status.conditions[0].status)')"
    else
        echo "❌ Service not running"
        exit 1
    fi

# Clean up Docker images
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    docker image rm {{service_name}} {{image_tag}} || true
    docker image prune -f