#!/usr/bin/env bash
# One-time setup to run the Remix web app on Vercel (private) against the Cloud Run API.
# Run from the repo root after `vercel login`. Safe to re-run: secrets are only created when missing,
# and Vercel env values are overwritten (--force). Secret values are never printed.
#
# What it does:
#   1. Creates bigbuck-edge-secret in Secret Manager (the header the API requires once it is public) and lets
#      the Cloud Run runtime service account read it.
#   2. Sets the web app's Vercel env (production + preview): RAILS_API_URL, SESSION_SECRET (new, Vercel-only),
#      BIGBUCK_EDGE_SECRET (same value as step 1), LAB_CREDENTIAL_STORE=cookie.
#   3. Removes the public <project>.vercel.app domain (PUBLIC_DOMAIN), so every address is behind Vercel login.
# Afterwards: deploy the API with API_INGRESS=all and WEB_APP_URL set (see the end of this script), then
# `vercel deploy --prod` from the repo root.
set -euo pipefail

GCP_PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}"
SCOPE="${VERCEL_SCOPE:?Set VERCEL_SCOPE to your Vercel team slug}"
PROJECT="${VERCEL_PROJECT:?Set VERCEL_PROJECT to your Vercel project name}"
API_URL="${API_URL:?Set API_URL to your Cloud Run API URL, e.g. https://bigbuck-api-<project-number>.<region>.run.app}"
RUNTIME_SA="bigbuck-runtime@${GCP_PROJECT}.iam.gserviceaccount.com"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-${PROJECT}.vercel.app}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
umask 077

if gcloud secrets describe bigbuck-edge-secret --project="${GCP_PROJECT}" >/dev/null 2>&1; then
  echo "edge secret exists; reusing it"
  gcloud secrets versions access latest --secret=bigbuck-edge-secret --project="${GCP_PROJECT}" > "${work}/edge"
else
  openssl rand -hex 32 | tr -d '\n' > "${work}/edge"
  gcloud secrets create bigbuck-edge-secret --project="${GCP_PROJECT}" --replication-policy=automatic \
    --data-file="${work}/edge" --quiet
fi
gcloud secrets add-iam-policy-binding bigbuck-edge-secret --project="${GCP_PROJECT}" \
  --member="serviceAccount:${RUNTIME_SA}" --role=roles/secretmanager.secretAccessor --quiet >/dev/null
echo "1/3 Secret Manager: bigbuck-edge-secret ready"

openssl rand -base64 48 | tr -d '\n' > "${work}/session"
printf '%s' "${API_URL}" > "${work}/api"
printf 'cookie' > "${work}/store"
for target in production preview; do
  vercel env add BIGBUCK_EDGE_SECRET "${target}" --scope "${SCOPE}" --project "${PROJECT}" --sensitive --force < "${work}/edge" >/dev/null
  vercel env add SESSION_SECRET "${target}" --scope "${SCOPE}" --project "${PROJECT}" --sensitive --force < "${work}/session" >/dev/null
  vercel env add RAILS_API_URL "${target}" --scope "${SCOPE}" --project "${PROJECT}" --force < "${work}/api" >/dev/null
  vercel env add LAB_CREDENTIAL_STORE "${target}" --scope "${SCOPE}" --project "${PROJECT}" --force < "${work}/store" >/dev/null
done
echo "2/3 Vercel env set for production and preview"

if vercel api "/v9/projects/${PROJECT}/domains/${PUBLIC_DOMAIN}" --scope "${SCOPE}" --silent >/dev/null 2>&1; then
  vercel api "/v9/projects/${PROJECT}/domains/${PUBLIC_DOMAIN}" -X DELETE --scope "${SCOPE}" --silent
  echo "3/3 removed public domain ${PUBLIC_DOMAIN}"
else
  echo "3/3 ${PUBLIC_DOMAIN} already removed"
fi

cat <<EOF

Next:
  APPLY=1 API_INGRESS=all WEB_APP_URL=https://${PROJECT}.vercel.app script/gcp-launch.sh build
  APPLY=1 API_INGRESS=all WEB_APP_URL=https://${PROJECT}.vercel.app script/gcp-launch.sh deploy
  vercel deploy --prod --scope ${SCOPE}      # from the repo root
EOF
