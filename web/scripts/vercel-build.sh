#!/usr/bin/env bash
# Vercel build (web/vercel.json). The project root is web/, but the lab and docs read files from the rest of
# the repo at runtime: the OpenAPI contract, the GraphQL schema, and the built SDK, CLI and MCP server the lab
# runs as child processes. Build those, drop their dev dependencies, and copy them into web/.repo, which the
# function bundles (app/data/lab/catalog.ts points repoRoot there when VERCEL is set).
set -euo pipefail
cd "$(dirname "$0")/../.."
for pkg in sdk cli mcp; do
  pnpm --dir "$pkg" install --frozen-lockfile
  pnpm --dir "$pkg" run build
done
pnpm --dir cli prune --prod
pnpm --dir mcp prune --prod
rm -rf web/.repo && mkdir -p web/.repo/cli/src
cp -R openapi schema.graphql sdk mcp web/.repo/
cp -R cli/dist cli/node_modules cli/package.json cli/presets web/.repo/cli/
cp cli/src/cli.ts web/.repo/cli/src/
# pnpm's file:../sdk dependency is a symlink into .pnpm; a plain cp -R leaves a dangling
# link inside web/.repo. Materialize a real SDK copy for the lab CLI and MCP children.
for pkg in cli mcp; do
  mkdir -p "web/.repo/$pkg/node_modules/@bigbuck"
  rm -rf "web/.repo/$pkg/node_modules/@bigbuck/sdk"
  cp -R web/.repo/sdk "web/.repo/$pkg/node_modules/@bigbuck/sdk"
done
# NFT does not always pick up .repo/schema.graphql from the dynamic repoRoot read; place a
# copy where import.meta.url in docs.ts can see it so the GraphQL reference page bundles.
cp schema.graphql web/docs/schema.graphql

# Compile every browser module now and serve them from the CDN; the function reads the manifest
# (app/assets.ts) and never runs the asset compiler, whose native binaries Vercel's tracer cannot bundle.
(cd web && env -u VERCEL NODE_ENV=production node --import remix/node-tsx scripts/prebuild-assets.ts)
du -sh web/.repo
