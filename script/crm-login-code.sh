#!/usr/bin/env bash
# Prints a fresh one-time web sign-in code (2 minute life) for the org's owner, the same handoff the
# Google flow redirects with: open /session/login?code=<code>. Local development databases only.
set -euo pipefail
cd "$(dirname "$0")/.."
export MYSQL_PORT="${MYSQL_PORT:-3307}" MYSQL_USER="${MYSQL_USER:-bigbuck}" MYSQL_PASSWORD="${MYSQL_PASSWORD:-bigbuck}"
ORG_ID="${1:?organization id}" bin/rails runner '
  Current.organization_id = ENV.fetch("ORG_ID")
  owner = Membership.joins(:role).find_by!(roles: { key: "owner" })
  Current.actor_id = owner.user_id
  issued = CredentialIssuer.call(kind: "handoff", name: "crm-e2e sign-in", user: owner.user,
    expires_at: CredentialIssuer::HANDOFF_TTL.from_now, created_by: owner.user)
  puts issued.token' | tail -1
