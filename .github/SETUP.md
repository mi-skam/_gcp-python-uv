# CI/CD Setup Guide

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Artifact Registry** repository created
3. **Service Account** with proper permissions
4. **GitHub repository** with secrets configured
5. **direnv** installed (optional, for environment variable management)

## Environment Setup

### Option 1: Using direnv (Recommended)

1. **Install direnv**: https://direnv.net/docs/installation.html
2. **Configure environment variables**: Edit `.envrc` and update `GCP_PROJECT_ID`
3. **Allow direnv**: `direnv allow .`

### Option 2: Manual Environment Variables

```bash
# Set up environment variables for this session
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="europe-west3"
export ARTIFACT_REGISTRY_REPO="cloud-run-apps"
export SERVICE_NAME="gcp-python-uv"
export GITHUB_SERVICE_ACCOUNT_NAME="github-actions"
export GITHUB_SA_KEY_FILE="github-actions-key.json"
export SERVICE_ACCOUNT_EMAIL="${GITHUB_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
```

## 1. Create Google Cloud Resources

### Create Artifact Registry Repository
```bash
gcloud artifacts repositories create $ARTIFACT_REGISTRY_REPO \
  --repository-format=docker \
  --location=$GCP_REGION \
  --description="Docker images for CI/CD"
```

### Create Service Account
```bash
# Create service account
gcloud iam service-accounts create $GITHUB_SERVICE_ACCOUNT_NAME \
  --display-name="GitHub Actions" \
  --description="Service account for GitHub Actions CI/CD"

# Assign required roles
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# Create and download service account key
gcloud iam service-accounts keys create $GITHUB_SA_KEY_FILE \
  --iam-account=$SERVICE_ACCOUNT_EMAIL
```

## 2. Configure GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following **Repository secrets**:

| Secret Name | Value | Source |
|-------------|-------|--------|
| `GCP_PROJECT_ID` | `$GCP_PROJECT_ID` | From your environment |
| `GCP_REGION` | `$GCP_REGION` | From your environment |
| `GCP_SERVICE_ACCOUNT_KEY` | `contents of $GITHUB_SA_KEY_FILE` | Generated JSON key file |

### Quick Commands for GitHub Secrets

```bash
# Display values for GitHub Secrets setup
echo "GCP_PROJECT_ID: $GCP_PROJECT_ID"
echo "GCP_REGION: $GCP_REGION"
echo ""
echo "GCP_SERVICE_ACCOUNT_KEY contents:"
cat $GITHUB_SA_KEY_FILE
```

## 3. Verify Setup

### Test CI Pipeline
1. Create a pull request
2. Check that CI workflow runs successfully
3. Verify Docker build completes

### Test Release Pipeline
1. Create a new tag: `git tag v0.1.1 && git push origin v0.1.1`
2. Check GitHub Actions for release workflow
3. Verify deployment to Cloud Run
4. Check GitHub release is created

## 4. Security Considerations

- **Service Account Key**: Stored securely in GitHub Secrets
- **Least Privilege**: Service account has minimal required permissions
- **Container Security**: Runs as non-root user
- **Network Security**: Cloud Run handles HTTPS termination

## 5. Cost Management

- **Cloud Run**: Pay per request (no idle charges)
- **Artifact Registry**: Storage costs for Docker images
- **Build Minutes**: GitHub Actions included in free tier

### Clean up unused resources:
```bash
# Delete old images (keep last 10 versions)
gcloud artifacts docker images list \
  --repository=$ARTIFACT_REGISTRY_REPO \
  --location=$GCP_REGION \
  --limit=10 \
  --sort-by=~create_time \
  --format="value(name)" | \
  xargs -I {} gcloud artifacts docker images delete {} --quiet
```

## 6. Monitoring

- **GitHub Actions**: View workflow runs in Actions tab
- **Cloud Run Logs**: `gcloud run services logs read $SERVICE_NAME --region=$GCP_REGION`
- **Cloud Monitoring**: Set up alerts for service health

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify service account key is correct
   - Check IAM permissions

2. **Build Failed**
   - Review GitHub Actions logs
   - Test Docker build locally

3. **Deployment Failed**
   - Check Cloud Run service logs
   - Verify image was pushed to Artifact Registry

4. **Service Unreachable**
   - Confirm `--allow-unauthenticated` flag
   - Check Cloud Run service URL