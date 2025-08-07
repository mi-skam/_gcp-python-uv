# justfile for gcp-python-uv project
project_id := `gcloud config get-value project`
region := "europe-west3"
artifact_registry_repo := "cloud-run-apps"
service_name := "gcp-python-uv"
port := "8080"

# Default target
default:
    @just --list

# Build the Docker image
build:
    docker build -t {{service_name}} .

# Update dependencies with uv
install:
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

# Check if authenticated with gcloud
check-auth:
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
setup-registry: check-auth
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
deploy: setup-registry
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔨 Building Docker image for Cloud Run (AMD64)..."
    docker build --platform linux/amd64 -t {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest .
    
    echo "📤 Pushing to Artifact Registry..."
    docker push {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest
    
    echo "🚀 Deploying to Cloud Run..."
    gcloud run deploy {{service_name}} \
        --image {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest \
        --platform managed \
        --region {{region}} \
        --allow-unauthenticated \
        --project {{project_id}}
    
    echo "✅ Deployment complete!"
    echo "🌐 Service URL: $(gcloud run services describe {{service_name}} --region={{region}} --format='value(status.url)')"

# Deploy to Google Cloud Run (authenticated access only)
deploy-secure: setup-registry
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔨 Building Docker image for Cloud Run (AMD64)..."
    docker build --platform linux/amd64 -t {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest .
    
    echo "📤 Pushing to Artifact Registry..."
    docker push {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest
    
    echo "🚀 Deploying to Cloud Run (secure mode)..."
    gcloud run deploy {{service_name}} \
        --image {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_registry_repo}}/{{service_name}}:latest \
        --platform managed \
        --region {{region}} \
        --no-allow-unauthenticated \
        --project {{project_id}}
    
    echo "✅ Deployment complete (authenticated access only)!"
    echo "🔒 Service URL: $(gcloud run services describe {{service_name}} --region={{region}} --format='value(status.url)')"
    echo "ℹ️  To access: gcloud run services proxy {{service_name}} --region={{region}}"

# Delete Cloud Run service to avoid costs
teardown:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🗑️  Deleting Cloud Run service..."
    if gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} &>/dev/null; then
        gcloud run services delete {{service_name}} --region {{region}} --project {{project_id}} --quiet
        echo "✅ Service deleted"
    else
        echo "ℹ️  Service not found (may already be deleted)"
    fi

# Clean up Docker images
clean:
    docker image rm {{service_name}} || true
    docker image prune -f