# syntax=docker/dockerfile:1
# Combined image: standalone happy-server (PGlite, no Redis/Postgres/S3) that also serves
# the prebuilt Expo web UI as static files on the same origin. arm64.
#
# Slim build: ship only happy-server's PRODUCTION node_modules (via `pnpm deploy --prod`),
# which drops happy-app's Expo/React-Native dependency tree (the bulk of the image). The server
# runs from TS source via `tsx`, which resolves the `@/*` tsconfig path aliases and handles the
# ESM<->CJS interop (e.g. @prisma/client named imports) that an ESM bundle cannot.
ARG HAPPY_REF=e10e51979143f4ffa9ead16c210af72c9864ac80

# ---- Stage 1: clone source, install deps, build web UI, deploy prod server ----
FROM node:20 AS builder
ARG HAPPY_REF
RUN apt-get update && apt-get install -y python3 make g++ build-essential git \
    && rm -rf /var/lib/apt/lists/*
RUN corepack enable && corepack prepare pnpm@10.11.0 --activate
WORKDIR /repo
# Shallow-fetch the exact ref (commit SHA, tag, or branch). GitHub supports fetch-by-SHA.
RUN git init -q . \
 && git remote add origin https://github.com/slopus/happy.git \
 && git fetch --depth 1 origin "${HAPPY_REF}" \
 && git checkout -q FETCH_HEAD
# Hoisted install (repo default). Skip the happy-wire postinstall build; build it explicitly next.
RUN SKIP_HAPPY_WIRE_BUILD=1 pnpm install --frozen-lockfile
RUN pnpm --filter @slopus/happy-wire build
# Export the web UI to packages/happy-app/dist
RUN pnpm --filter happy-app exec expo export --platform web --output-dir dist
# Production-only deployment of the server: drops happy-app's deps, injects the built
# @slopus/happy-wire workspace dep, and runs `prisma generate` via the package postinstall.
# Try the modern deploy; fall back to --legacy for workspaces without inject-workspace-packages.
RUN pnpm --filter happy-server-self-host deploy --prod /deploy \
 || { rm -rf /deploy; pnpm --filter happy-server-self-host deploy --prod --legacy /deploy; }
# pnpm's isolated deploy layout leaves an incomplete generated Prisma client: @prisma/client
# re-exports `.prisma/client/default`, but the deploy tree's `.prisma/client` lacks the schema's
# enums (e.g. RelationshipStatus) → ESM named imports fail. Overlay the fully-generated client
# (.prisma/client + the @prisma/client re-export stub) from the hoisted install, which is complete.
RUN rm -rf /deploy/node_modules/.prisma /deploy/node_modules/@prisma/client \
 && cp -R /repo/node_modules/.prisma /deploy/node_modules/.prisma \
 && cp -R /repo/node_modules/@prisma/client /deploy/node_modules/@prisma/client
# Visibility: sizes that land in the runtime image
RUN echo "=== SIZES ===" && du -sh /deploy/node_modules && du -sh /repo/packages/happy-app/dist

# ---- Stage 2: runtime ----
FROM node:20-slim AS runner
RUN apt-get update && apt-get install -y ffmpeg curl && rm -rf /var/lib/apt/lists/*
# tsx runs the TS server directly (resolves @/* path aliases + ESM/CJS interop). Pin to repo's major.
RUN npm install -g tsx@4
ENV NODE_ENV=production \
    DATA_DIR=/data \
    PGLITE_DIR=/data/pglite \
    HAPPY_STATIC_DIR=/app/webapp
WORKDIR /app
# Production node_modules (incl. generated @prisma/client, pglite, sharp, fastify, socket.io, happy-wire)
COPY --from=builder /deploy/node_modules /app/node_modules
# package.json ("type": module) + tsconfig (baseUrl + @/* paths) + prisma migrations
COPY --from=builder /repo/packages/happy-server/package.json /app/package.json
COPY --from=builder /repo/packages/happy-server/tsconfig.json /app/tsconfig.json
COPY --from=builder /repo/packages/happy-server/prisma /app/prisma
# Server TS source (executed by tsx)
COPY --from=builder /repo/packages/happy-server/sources /app/sources
# Built web UI, served as static by the standalone server
COPY --from=builder /repo/packages/happy-app/dist /app/webapp
VOLUME /data
EXPOSE 3005
# migrate (PGlite) then serve
CMD ["sh", "-c", "tsx --tsconfig tsconfig.json sources/standalone.ts migrate && exec tsx --tsconfig tsconfig.json sources/standalone.ts serve"]
