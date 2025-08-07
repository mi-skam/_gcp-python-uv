# justfile for gcp-python-uv project

# ==================== Configuration ====================
# Load environment variables from .env file if it exists
set dotenv-load := true

# Core configuration (from .env or environment)
project_id := env_var_or_default("GCP_PROJECT_ID", `gcloud config get-value project`)
region := env_var("GCP_REGION")
service_name := env_var("SERVICE_NAME")

# Python configuration (single source of truth: .python-version)
python_version := `cat .python-version | tr -d '\n'`
python_image := env_var_or_default("PYTHON_IMAGE", "python:" + python_version + "-slim")

# Port configuration
port := env_var("PORT")
dev_local_port := env_var("DEV_LOCAL_PORT")

# Artifact Registry configuration
artifact_registry_repo := env_var("ARTIFACT_REGISTRY_REPO")
git_hash := `git rev-parse --short HEAD`
image_tag := region + "-docker.pkg.dev/" + project_id + "/" + artifact_registry_repo + "/" + service_name + ":" + git_hash

# ==================== Default Target ====================
# Show available commands
default:
    @just --list --unsorted

# ==================== Development Commands ====================
# Start development server with Docker Compose watch mode
dev port=dev_local_port:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Starting development server on http://localhost:{{port}}"
    echo "💡 Code changes will sync automatically with watch mode"
    echo "🛑 Press Ctrl+C to stop"
    DEV_LOCAL_PORT={{port}} docker compose up --watch


# Test production build locally
test-prod local_port=dev_local_port:
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'docker stop $(docker ps -q --filter ancestor={{service_name}}) 2>/dev/null' EXIT
    echo "🚀 Starting production container on http://localhost:{{local_port}}"
    echo "⚠️  Note: Code changes require rebuilding the container"
    docker run -p {{local_port}}:{{port}} -e PORT={{port}} --rm {{service_name}}

# ==================== Build Commands ====================
# Build Docker image (defaults to host platform for speed)
build platform="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{platform}}" ]; then
        echo "🔨 Building Docker image for host platform..."
        docker build --build-arg PYTHON_IMAGE={{python_image}} -t {{service_name}} -t {{image_tag}} .
    else
        echo "🔨 Building Docker image for platform {{platform}}..."
        docker build --platform {{platform}} --build-arg PYTHON_IMAGE={{python_image}} -t {{service_name}} -t {{image_tag}} .
    fi

# Update dependencies
update:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Updating dependencies with dockerized uv..."
    docker run --rm -v $(pwd):/app -w /app {{python_image}} sh -c "pip install uv && uv lock --upgrade"
    echo "✅ Dependencies updated in uv.lock"

# Clean up Docker images
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    docker image rm {{service_name}} {{image_tag}} 2>/dev/null || true
    docker image prune -f
    echo "🧹 Docker images cleaned"

# ==================== Deployment Commands ====================
# Deploy to Google Cloud Run
deploy: _validate-deployment _build-and-push
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Deploying to Cloud Run..."
    gcloud run deploy {{service_name}} \
        --image {{image_tag}} \
        --platform managed \
        --region {{region}} \
        --allow-unauthenticated \
        --project {{project_id}}
    echo "🌐 Service URL: $(gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} --format='value(status.url)')"

# Delete Cloud Run service
destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🗑️  Deleting Cloud Run service..."
    if gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} &>/dev/null; then
        gcloud run services delete {{service_name}} --region {{region}} --project {{project_id}} --quiet
        echo "✅ Service deleted"
    else
        echo "ℹ️  Service not found"
    fi

# ==================== Monitoring Commands ====================
# Check service status
status:
    #!/usr/bin/env bash
    set -euo pipefail
    if gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} &>/dev/null; then
        echo "✅ Service is deployed"
        echo "🌐 URL: $(gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} --format='value(status.url)')"
        echo "📊 Ready: $(gcloud run services describe {{service_name}} --region={{region}} --project={{project_id}} --format='value(status.conditions[0].status)')"
    else
        echo "❌ Service not deployed"
        exit 1
    fi

# View service logs
logs limit="50":
    gcloud logging read \
        "resource.type=cloud_run_revision AND resource.labels.service_name={{service_name}}" \
        --limit={{limit}} \
        --project={{project_id}} \
        --format=json \
        | jq -r 'reverse | .[] | "[\(.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y-%m-%d %H:%M"))] \(.textPayload // .jsonPayload.message // "No message")"'

# ==================== Private Recipes (Template Method Pattern) ====================
# Validate deployment prerequisites
_validate-deployment:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check project
    if [[ -z "{{project_id}}" || "{{project_id}}" == "(unset)" ]]; then
        echo "❌ No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    # Check tools
    for tool in gcloud docker; do
        if ! command -v $tool &> /dev/null; then
            echo "❌ $tool not found. Please install it."
            exit 1
        fi
    done
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo "❌ Not authenticated. Run: gcloud auth login"
        exit 1
    fi
    
    echo "✅ Deployment prerequisites validated"

# Build and push image (Factory pattern for Cloud Run images)
_build-and-push: _setup-registry
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Docker image for Cloud Run (linux/amd64)..."
    docker build --platform linux/amd64 --build-arg PYTHON_IMAGE={{python_image}} -t {{image_tag}} .
    echo "📤 Pushing to Artifact Registry..."
    docker push {{image_tag}}

# Setup Artifact Registry (Singleton pattern - ensures single repository)
_setup-registry:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Create repository if it doesn't exist
    if ! gcloud artifacts repositories describe {{artifact_registry_repo}} \
        --location={{region}} \
        --project={{project_id}} &>/dev/null; then
        echo "📦 Creating Artifact Registry repository..."
        gcloud artifacts repositories create {{artifact_registry_repo}} \
            --repository-format=docker \
            --location={{region}} \
            --project={{project_id}} \
            --description="Docker images for Cloud Run applications"
    fi
    
    # Configure Docker authentication
    gcloud auth configure-docker {{region}}-docker.pkg.dev --quiet