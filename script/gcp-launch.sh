#!/usr/bin/env bash
# Demo deployment to Google Cloud: Cloud SQL (MySQL) + Rails API on Cloud Run + Remix web on Cloud Run.
#
# SAFE BY DEFAULT: every state-changing command is printed, not run, until you set APPLY=1.
# Read-only lookups (project number, resource existence) always run, so the dry run shows real values.
#
#   export GCP_PROJECT=your-gcp-project-id
#   ./script/gcp-launch.sh plan            # print every step for all phases (dry run)
#   APPLY=1 ./script/gcp-launch.sh infra   # one phase at a time, after approval
#
# Phases, in order:  infra  build  migrate  deploy  seed  smoke      ("all" runs them in order)
# Also:              stop   (stop Cloud SQL to cut compute cost)   status   (read-only)
#
# Demo posture: BIGBUCK_DEMO_SIGN_IN=1 (passwordless email sign-in on lab sandboxes), no Google OAuth,
# Cloud Run scale-to-zero, no always-on worker. See research/gcp-demo-deploy-plan.md for what that costs you.

set -euo pipefail

: "${GCP_PROJECT:?Set GCP_PROJECT to your Google Cloud project id}"
GCP_REGION="${GCP_REGION:-us-central1}"
SQL_INSTANCE="${GCP_SQL_INSTANCE:-bigbuck-mysql}"
AR_REPO="${GCP_AR_REPO:-bigbuck}"
API_SERVICE="${GCP_API_SERVICE:-bigbuck-api}"
WEB_SERVICE="${GCP_WEB_SERVICE:-bigbuck-web}"
MYSQL_DATABASE="${MYSQL_DATABASE:-bigbuck_production}"
MYSQL_USER="${MYSQL_USER:-bigbuck}"
RUNTIME_SA_NAME="${GCP_RUNTIME_SA:-bigbuck-runtime}"
APPLY="${APPLY:-0}"

export CLOUDSDK_CORE_PROJECT="${GCP_PROJECT}"
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '==> %s\n' "$*" >&2; }
# Mutating command: print always, execute only with APPLY=1.
run() {
  printf '  $ %s\n' "$*" >&2
  if [ "${APPLY}" = "1" ]; then "$@"; fi
}
# Same, but the command text hides a secret on stdin: $1 is the secret value producer description.
run_stdin() {
  local desc="$1"; shift
  printf '  $ (%s) | %s\n' "${desc}" "$*" >&2
}

PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT}" --format='value(projectNumber)')"
RUNTIME_SA="${RUNTIME_SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com"
BUCKET="${GCP_PROJECT}-bigbuck-documents"
CONN="${GCP_PROJECT}:${GCP_REGION}:${SQL_INSTANCE}"
# Cloud Run's deterministic URL form, so API and web can be configured with each other's origin
# before either exists. `deploy` verifies the real URL matches.
API_HOST="${API_SERVICE}-${PROJECT_NUMBER}.${GCP_REGION}.run.app"
WEB_HOST="${WEB_SERVICE}-${PROJECT_NUMBER}.${GCP_REGION}.run.app"
API_URL="https://${API_HOST}"
WEB_URL="https://${WEB_HOST}"
# Where people open the web app. Defaults to the Cloud Run web service; set to the Vercel URL when Remix runs
# there (web/vercel.json). It feeds the API's WEB_ORIGIN(S), used for CORS and links back to the app.
WEB_APP_URL="${WEB_APP_URL:-${WEB_URL}}"
# internal: only the Cloud Run web service (same VPC) can reach the API. all: the Vercel-hosted web app calls
# it over the internet, so every request must carry the bigbuck-edge-secret header (lib/request_security.rb).
API_INGRESS="${API_INGRESS:-internal}"
REGISTRY="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}"
TAG="$(git -C "${ROOT}" rev-parse --short HEAD)"
API_IMAGE="${REGISTRY}/api:${TAG}"
WEB_IMAGE="${REGISTRY}/web:${TAG}"

exists() { "$@" >/dev/null 2>&1; }

# Env shared by the API service and the migrate/seed jobs. production.rb raises without ALLOWED_HOSTS.
# No value below contains a comma, so --set-env-vars can take them as-is.
api_env() {
  printf '%s' "RAILS_ENV=production,RAILS_LOG_TO_STDOUT=1,MYSQL_DATABASE=${MYSQL_DATABASE},MYSQL_USER=${MYSQL_USER}"
  printf '%s' ",CLOUD_SQL_CONNECTION_NAME=${CONN},GOOGLE_CLOUD_PROJECT=${GCP_PROJECT},BIGBUCK_DOCUMENT_BUCKET=${BUCKET}"
  printf '%s' ",BIGBUCK_ALLOWED_HOSTS=${API_HOST},WEB_ORIGINS=${WEB_APP_URL},WEB_ORIGIN=${WEB_APP_URL}"
  # BIGBUCK_DEMO_CANDIDATE_WRITES=1: candidates can apply on the lab careers page and answer offer links.
  # Safe only because the web service is private (IAM invoker = you); unset it if the web service goes public.
  # Nightly refresh is Cloud Scheduler → bigbuck-seed FORCE=1 at 03:00 America/New_York. RESET_AT makes
  # every refresh (including a manual daytime reseed) set resets_at to the next 3am ET so the schedule
  # never slips. INTERVAL_HOURS remains as the fallback when RESET_AT is unset (and for older images).
  printf '%s' ",BIGBUCK_DEMO_SIGN_IN=1,BIGBUCK_DEMO_ENRICH=1,BIGBUCK_DEMO_RESET_AT=03:00,BIGBUCK_DEMO_RESET_TZ=America/New_York,BIGBUCK_DEMO_INTERVAL_HOURS=168,BIGBUCK_DEMO_CANDIDATE_WRITES=1,SOLID_QUEUE_IN_PUMA=true,BIGBUCK_SKIP_DB_PREPARE=1"
}
api_secrets() {
  printf '%s' "MYSQL_PASSWORD=bigbuck-mysql-password:latest,SECRET_KEY_BASE=bigbuck-secret-key-base:latest"
  printf '%s' ",BIGBUCK_BOOTSTRAP_TOKEN=bigbuck-bootstrap-token:latest"
  if [ "${API_INGRESS}" = "all" ]; then printf '%s' ",BIGBUCK_EDGE_SECRET=bigbuck-edge-secret:latest"; fi
}

phase_infra() {
  log "infra: APIs, Cloud SQL (start + harden), database + user, secrets, bucket, runtime service account"
  run gcloud services enable run.googleapis.com sqladmin.googleapis.com artifactregistry.googleapis.com \
    cloudbuild.googleapis.com secretmanager.googleapis.com iam.googleapis.com storage.googleapis.com \
    compute.googleapis.com cloudscheduler.googleapis.com

  # Private by design: the API accepts only internal traffic, reached from the web service over Direct VPC
  # egress. That needs the default network's subnet to have Private Google Access (so *.run.app resolves
  # to Google's internal front end). No NAT or connector is created.
  if [ "${APPLY}" = "1" ]; then
    gcloud compute networks describe default >/dev/null || { echo "No default VPC network; create one or set up another." >&2; exit 1; }
  fi
  run gcloud compute networks subnets update default --region="${GCP_REGION}" --enable-private-ip-google-access

  # One patch: start the instance (it is STOPPED), set the flag db/structure.sql's audit triggers need
  # (restarts), turn on daily backups, and require encrypted connections.
  run gcloud sql instances patch "${SQL_INSTANCE}" --activation-policy=ALWAYS \
    --database-flags=log_bin_trust_function_creators=on \
    --backup-start-time=08:00 --ssl-mode=ENCRYPTED_ONLY --quiet

  exists gcloud sql databases describe "${MYSQL_DATABASE}" --instance="${SQL_INSTANCE}" || \
    run gcloud sql databases create "${MYSQL_DATABASE}" --instance="${SQL_INSTANCE}" --charset=utf8mb4 --collation=utf8mb4_0900_ai_ci

  # The secret exists from the earlier attempt; re-apply its value to the SQL user so they agree.
  run_stdin "gcloud secrets versions access latest --secret=bigbuck-mysql-password" \
    "gcloud sql users create|set-password ${MYSQL_USER} --host=% --password=-"
  if [ "${APPLY}" = "1" ]; then
    local pw; pw="$(gcloud secrets versions access latest --secret=bigbuck-mysql-password)"
    if gcloud sql users list --instance="${SQL_INSTANCE}" --format='value(name)' | grep -qx "${MYSQL_USER}"; then
      gcloud sql users set-password "${MYSQL_USER}" --host='%' --instance="${SQL_INSTANCE}" --password="${pw}" >/dev/null
    else
      gcloud sql users create "${MYSQL_USER}" --host='%' --instance="${SQL_INSTANCE}" --password="${pw}" >/dev/null
    fi
  fi

  for s in bigbuck-bootstrap-token bigbuck-session-secret; do
    if ! exists gcloud secrets describe "${s}"; then
      run_stdin "openssl rand -hex 32" "gcloud secrets create ${s} --data-file=-"
      if [ "${APPLY}" = "1" ]; then openssl rand -hex 32 | tr -d '\n' | gcloud secrets create "${s}" --data-file=- >/dev/null; fi
    fi
  done

  exists gcloud storage buckets describe "gs://${BUCKET}" || \
    run gcloud storage buckets create "gs://${BUCKET}" --location="${GCP_REGION}" \
      --uniform-bucket-level-access --public-access-prevention

  # Least privilege: a dedicated runtime identity instead of the default compute service account.
  exists gcloud iam service-accounts describe "${RUNTIME_SA}" || \
    run gcloud iam service-accounts create "${RUNTIME_SA_NAME}" --display-name="Big Buck runtime"
  run gcloud projects add-iam-policy-binding "${GCP_PROJECT}" --member="serviceAccount:${RUNTIME_SA}" \
    --role=roles/cloudsql.client --condition=None
  for s in bigbuck-mysql-password bigbuck-secret-key-base bigbuck-bootstrap-token bigbuck-session-secret; do
    run gcloud secrets add-iam-policy-binding "${s}" --member="serviceAccount:${RUNTIME_SA}" \
      --role=roles/secretmanager.secretAccessor
  done
  run gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" --member="serviceAccount:${RUNTIME_SA}" \
    --role=roles/storage.objectAdmin
}

phase_build() {
  log "build: API + web images via Cloud Build (${TAG}). Commit/stash first: the image is built from the working tree."
  run gcloud builds submit "${ROOT}" --config="${ROOT}/script/cloudbuild.yaml" \
    --substitutions="_API_IMAGE=${API_IMAGE},_WEB_IMAGE=${WEB_IMAGE}"
}

job() { # job <name> <timeout> <memory> <args...>
  local name="$1" timeout="$2" memory="$3"; shift 3
  run gcloud run jobs deploy "${name}" --region="${GCP_REGION}" --image="${API_IMAGE}" \
    --service-account="${RUNTIME_SA}" --set-cloudsql-instances="${CONN}" \
    --set-env-vars="$(api_env)" --set-secrets="$(api_secrets)" \
    --command=/rails/bin/docker-entrypoint --args="$(IFS=,; echo "$*")" \
    --memory="${memory}" --cpu=1 --task-timeout="${timeout}" --max-retries=0
  run gcloud run jobs execute "${name}" --region="${GCP_REGION}" --wait
}

phase_migrate() {
  log "migrate: load/upgrade schema (db/structure.sql incl. audit triggers) as a one-off job, not at service boot"
  job bigbuck-migrate 15m 1Gi ./bin/rails db:prepare
}

phase_deploy() {
  log "deploy: API (one instance kept warm) then web (scale-to-zero; capped at 1 instance because lab credentials live on local disk)"
  run gcloud run deploy "${API_SERVICE}" --region="${GCP_REGION}" --image="${API_IMAGE}" \
    --service-account="${RUNTIME_SA}" --allow-unauthenticated --ingress="${API_INGRESS}" --port=8080 \
    --memory=1Gi --cpu=1 --cpu-boost --min-instances=1 --max-instances=2 --timeout=300 \
    --set-cloudsql-instances="${CONN}" --set-env-vars="$(api_env)" --set-secrets="$(api_secrets)"

  # The web app is hosted elsewhere (Vercel) when WEB_APP_URL points away from Cloud Run: deploy only the API.
  if [ "${WEB_APP_URL}" != "${WEB_URL}" ]; then
    log "deploy: skipping Cloud Run web (web app is served at ${WEB_APP_URL})"
    if [ "${APPLY}" = "1" ]; then
      service_urls "${API_SERVICE}" | grep -qxF "${API_URL}" || {
        echo "Cloud Run does not serve the predicted API URL (${API_URL}); set API_HOST and re-run." >&2; exit 1; }
    fi
    return 0
  fi

  run gcloud run deploy "${WEB_SERVICE}" --region="${GCP_REGION}" --image="${WEB_IMAGE}" \
    --service-account="${RUNTIME_SA}" --no-allow-unauthenticated --ingress=all --port=8080 \
    --network=default --subnet=default --vpc-egress=all-traffic \
    --memory=1Gi --cpu=1 --cpu-boost --min-instances=0 --max-instances=1 --timeout=300 \
    --set-env-vars="RAILS_API_URL=${API_URL}" --set-secrets="SESSION_SECRET=bigbuck-session-secret:latest"

  # Only the operator can open the web UI (IAM invoker). Nobody else, no allUsers.
  run gcloud run services add-iam-policy-binding "${WEB_SERVICE}" --region="${GCP_REGION}" \
    --member="user:$(gcloud config get-value account 2>/dev/null)" --role=roles/run.invoker

  if [ "${APPLY}" = "1" ]; then
    local got_api got_web
    got_api="$(service_urls "${API_SERVICE}")"
    got_web="$(service_urls "${WEB_SERVICE}")"
    printf '%s\n' "${got_api}" | grep -qxF "${API_URL}" && printf '%s\n' "${got_web}" | grep -qxF "${WEB_URL}" || {
      echo "Cloud Run does not serve the predicted URLs (api=${API_URL} web=${WEB_URL}); the env vars baked in are wrong." >&2
      echo "Cloud Run reports: api=$(echo ${got_api}) web=$(echo ${got_web})" >&2
      echo "Re-run deploy after setting API_HOST/WEB_HOST overrides." >&2; exit 1; }
  fi
}

# Every URL Cloud Run serves for a service, one per line. status.url only reports the legacy
# hash-style URL (…-<hash>-uc.a.run.app); the deterministic one we predict and bake into env
# (…-<project number>.<region>.run.app) is listed in the run.googleapis.com/urls annotation.
service_urls() {
  gcloud run services describe "$1" --region="${GCP_REGION}" --format=json | python3 -c '
import json, sys
service = json.load(sys.stdin)
urls = [service.get("status", {}).get("url", "")]
urls += json.loads(service.get("metadata", {}).get("annotations", {}).get("run.googleapis.com/urls", "[]"))
print("\n".join(u for u in urls if u))'
}

phase_seed() {
  log "seed: prepare the lab sandboxes (template copy; first run builds the snapshot) and schedule the nightly FORCE refresh"
  # Enriched ~800-person template (PDFs to GCS) routinely exceeds 30m on Cloud SQL.
  job bigbuck-seed 90m 2Gi ./bin/rails demo:prepare
  ensure_nightly_seed_schedule
}

# Cloud Scheduler → Cloud Run Job at 03:00 America/New_York with FORCE=1. Independent of resets_at so a
# manual daytime demo:prepare cannot postpone tonight's run. App Engine is a Scheduler prerequisite in
# this project; create it once in us-central if missing.
ensure_nightly_seed_schedule() {
  local sched_sa_name="bigbuck-scheduler"
  local sched_sa="${sched_sa_name}@${GCP_PROJECT}.iam.gserviceaccount.com"
  local job_name="bigbuck-seed-nightly"
  local uri="https://${GCP_REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${GCP_PROJECT}/jobs/bigbuck-seed:run"
  local body='{"overrides":{"containerOverrides":[{"env":[{"name":"FORCE","value":"1"}]}]}}'

  log "schedule: ${job_name} daily 03:00 America/New_York → bigbuck-seed FORCE=1"
  exists gcloud iam service-accounts describe "${sched_sa}" || \
    run gcloud iam service-accounts create "${sched_sa_name}" --display-name="Big Buck nightly seed scheduler"
  # Cloud Scheduler needs an App Engine app in the region (once per project).
  if ! exists gcloud app describe; then
    run gcloud app create --region="${GCP_REGION}"
  fi
  # Scheduler's service agent must mint OAuth tokens for sched_sa; sched_sa must be able to run the job.
  run gcloud iam service-accounts add-iam-policy-binding "${sched_sa}" \
    --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloudscheduler.iam.gserviceaccount.com" \
    --role=roles/iam.serviceAccountTokenCreator
  run gcloud run jobs add-iam-policy-binding bigbuck-seed --region="${GCP_REGION}" \
    --member="serviceAccount:${sched_sa}" --role=roles/run.invoker
  run gcloud projects add-iam-policy-binding "${GCP_PROJECT}" --member="serviceAccount:${sched_sa}" \
    --role=roles/run.developer --condition=None
  if exists gcloud scheduler jobs describe "${job_name}" --location="${GCP_REGION}"; then
    # update uses --update-headers; create uses --headers.
    run gcloud scheduler jobs update http "${job_name}" --location="${GCP_REGION}" \
      --schedule="0 3 * * *" --time-zone="America/New_York" \
      --uri="${uri}" --http-method=POST \
      --message-body="${body}" --update-headers="Content-Type=application/json" \
      --oauth-service-account-email="${sched_sa}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"
  else
    run gcloud scheduler jobs create http "${job_name}" --location="${GCP_REGION}" \
      --schedule="0 3 * * *" --time-zone="America/New_York" \
      --uri="${uri}" --http-method=POST \
      --message-body="${body}" --headers="Content-Type=application/json" \
      --oauth-service-account-email="${sched_sa}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"
  fi
}

phase_smoke() {
  log "smoke: health + sign-in page (read-only)"
  [ "${APPLY}" = "1" ] || { log "(skipped in dry run: nothing is deployed yet)"; return 0; }
  # The API is internal-only, so it is checked through the web service (which calls it) with an identity token.
  local tok; tok="$(gcloud auth print-identity-token)"
  for u in "${WEB_URL}/" "${WEB_URL}/session"; do
    printf '  %s -> ' "${u}" >&2
    curl -sS -o /dev/null -L -H "Authorization: Bearer ${tok}" -w '%{http_code} in %{time_total}s\n' --max-time 120 "${u}" >&2 || echo failed >&2
  done
  printf '  public, no token (must be 403/401) %s -> ' "${WEB_URL}/" >&2
  curl -sS -o /dev/null -w '%{http_code}\n' --max-time 30 "${WEB_URL}/" >&2 || echo failed >&2
  printf '  public API (must be 404/403) %s -> ' "${API_URL}/up" >&2
  curl -sS -o /dev/null -w '%{http_code}\n' --max-time 30 "${API_URL}/up" >&2 || echo failed >&2
}

phase_stop() {
  log "stop: stop Cloud SQL (apps will error until infra is re-run). Keeps data; disk still billed."
  run gcloud sql instances patch "${SQL_INSTANCE}" --activation-policy=NEVER --quiet
}

phase_status() {
  gcloud sql instances list --format='table(name,state,settings.tier)'
  gcloud run services list --region="${GCP_REGION}" 2>&1 || true
  gcloud run jobs list --region="${GCP_REGION}" 2>&1 || true
}

case "${1:-plan}" in
  plan) APPLY=0; for p in infra build migrate deploy seed smoke; do "phase_${p}"; done ;;
  all) for p in infra build migrate deploy seed smoke; do "phase_${p}"; done ;;
  infra|build|migrate|deploy|seed|smoke|stop|status) "phase_${1}" ;;
  *) echo "usage: $0 {plan|infra|build|migrate|deploy|seed|smoke|stop|status|all}" >&2; exit 2 ;;
esac
[ "${APPLY}" = "1" ] || log "DRY RUN: nothing was changed. Re-run with APPLY=1 to execute."
