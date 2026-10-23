
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/vish/projects/hello-production-api"
SERVICE_NAME="hello-production-api"
HEALTH_URL="https://127.0.0.1/health"

cd "$PROJECT_DIR"

echo "🚀 Starting deployment..."

# 1. Ensure there are no uncommitted changes
if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# 2. Ensure we're deploying main
BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
  echo "❌ Expected branch 'main', found '$BRANCH'."
  exit 1
fi

# 3. Fetch approved code from GitHub
echo "📥 Fetching latest code..."
git fetch origin main

# Refuse to deploy if local main has commits not on origin/main
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "❌ Local main has commits not contained in origin/main."
  echo "Review Git history before deploying."
  exit 1
fi

echo "📦 Updating code..."
git merge --ff-only origin/main

# 4. Install dependencies and run tests
echo "📦 Installing dependencies..."
npm ci

echo "🧪 Running tests..."
npm test

# 5. Restart the service
echo "🔄 Restarting $SERVICE_NAME..."
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl is-active --quiet "$SERVICE_NAME"

# 6. Verify the API through Nginx
echo "🏥 Checking API health..."
if ! curl --fail --silent --show-error \
  --insecure --max-time 10 "$HEALTH_URL"; then
  echo
  echo "❌ Health check failed. Inspect service logs:"
  echo "sudo journalctl -u $SERVICE_NAME -n 50 --no-pager"
  exit 1
fi

echo
echo "✅ Deployment checks completed!"
