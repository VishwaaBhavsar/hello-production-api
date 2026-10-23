
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/vish/projects/hello-production-api"
SERVICE_NAME="hello-production-api"
HEALTH_URL="https://127.0.0.1/health"

cd "$PROJECT_DIR"

echo "🚀 Starting deployment..."

# 1. Require a clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ Working tree is not clean."
  echo "Commit or stash changes before deploying."
  exit 1
fi

# 2. Require main branch
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "❌ Deployments must run from main."
  exit 1
fi

# 3. Fetch the latest approved code
echo "📥 Fetching origin/main..."
git fetch origin main

TARGET="$(git rev-parse origin/main)"

# Refuse local-only commits and divergent history
if ! git merge-base --is-ancestor HEAD "$TARGET"; then
  echo "❌ Local main has commits not contained in origin/main."
  echo "Push or review those commits before deploying."
  exit 1
fi

# 4. Test incoming code in a temporary Git worktree
TEST_DIR="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$TEST_DIR" >/dev/null 2>&1 || true
  rmdir "$TEST_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "🧪 Testing incoming code before updating main..."
git worktree add --detach "$TEST_DIR" "$TARGET"
(
  cd "$TEST_DIR"
  npm ci
  npm test
)

echo "✅ Tests passed."

# 5. Update main only after tests pass
echo "📦 Updating local main..."
git merge --ff-only "$TARGET"

# 6. Restart the service
echo "🔄 Restarting $SERVICE_NAME..."
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl is-active --quiet "$SERVICE_NAME"


# 7. Verify health through Nginx, retrying during startup
echo "🏥 Checking API health..."

HEALTHY=false

for attempt in {1..10}; do
  if curl --fail --silent --show-error \
    --insecure --max-time 3 "$HEALTH_URL"; then
    HEALTHY=true
    break
  fi

  echo "Health check attempt $attempt failed; retrying in 3 seconds..."
  sleep 3
done

if [[ "$HEALTHY" != "true" ]]; then
  echo "❌ Health check failed after retries."
  echo "Inspect logs with:"
  echo "sudo journalctl -u $SERVICE_NAME -n 50 --no-pager"
  exit 1
fi

echo
echo "✅ Deployment checks completed!"

