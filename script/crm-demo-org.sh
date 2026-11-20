#!/usr/bin/env bash
# Provisions a throwaway NON-demo org, fills it with crm:demo_seed data and mints an owner token.
# Writes CRM_OWNER_TOKEN / CRM_SAM_USER_ID / CRM_ORG to $1 (default /tmp/crm-e2e.env) for
# `pnpm --dir web run verify:crm`. Local development databases only.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-/tmp/crm-e2e.env}"
export MYSQL_PORT="${MYSQL_PORT:-3307}" MYSQL_USER="${MYSQL_USER:-bigbuck}" MYSQL_PASSWORD="${MYSQL_PASSWORD:-bigbuck}"

org_id="$(bin/rails runner '
  r = OrganizationProvisioner.call(name: "CRM walkthrough", slug: "crm-#{SecureRandom.hex(3)}",
    owner_email: "owner-#{SecureRandom.hex(2)}@crm-walk.test", owner_name: "Owner")
  puts r[:organization].id' | tail -1)"

bin/rails crm:demo_seed ORG="$org_id" >/dev/null

ORG_ID="$org_id" OUT="$out" bin/rails runner '
  Current.organization_id = ENV.fetch("ORG_ID")
  owner = Membership.joins(:role).find_by!(roles: { key: "owner" })
  Current.actor_id = owner.user_id
  issued = CredentialIssuer.call(kind: "personal", name: "crm-e2e", user: owner.user, scopes: Scopes::ALL, created_by: owner.user)
  sam = User.find_by!(email: "sam.recruiter@demo.bigbuck.test")
  File.write(ENV.fetch("OUT"), "CRM_OWNER_TOKEN=#{issued.token}\nCRM_SAM_USER_ID=#{sam.id}\nCRM_ORG=#{ENV.fetch("ORG_ID")}\n")'

echo "org $org_id ready; env written to $out"
