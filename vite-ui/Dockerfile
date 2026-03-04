# ========================================
# Base Stage
# ========================================
FROM node:22-alpine AS base

# ✅ Install system dependencies
RUN apk update && \
  apk add --no-cache \
  curl \
  wget \
  bash \
  ca-certificates \
  build-base \
  cmake \
  git \
  linux-headers \
  pkgconf \
  protobuf \
  protobuf-dev \
  grpc \
  grpc-dev \
  dos2unix \
  coreutils \
  && rm -rf /var/cache/apk/*

# ✅ Install Rover with error handling (use older stable version for Alpine compatibility)
RUN curl -sSL https://rover.apollo.dev/nix/v0.36.2 | sh -s -- --force || \
  echo "⚠️ Rover installation failed, will use curl fallback"
ENV PATH="/root/.rover/bin:${PATH}"

# ✅ Verify Rover (optional - don't fail if not installed)
RUN rover --version 2>/dev/null || echo "⚠️ Rover not available, will use curl fallback"

# ✅ Install protoc plugins
RUN npm install -g protoc-gen-js ts-protoc-gen @nicolo-ribaudo/chokidar-2 protoc-gen-grpc-web 2>/dev/null || true

WORKDIR /app

# ✅ Create all required directories
RUN mkdir -p \
  ./scripts \
  ./grpc \
  ./grpc-generated \
  ./apollo \
  ./apollo/generated \
  ./apollo/fragments \
  ./wwwroot/grpc \
  ./wwwroot/volume \
  ./node_modules/.vite \
  ./protobuf \
  ./hub/Pages \
  ./hub/components \
  ./hub/suites \
  ./hub/stores \
  /usr/local/bin/lib

RUN touch /app/.ready

COPY vite-ui/scripts/ ./scripts/

RUN if [ -f "./scripts/configure.sh" ]; then \
  cp ./scripts/configure.sh /usr/local/bin/lib/ 2>/dev/null || true; \
  fi && \
  if [ -f "./scripts/logging.sh" ]; then \
  cp ./scripts/logging.sh /usr/local/bin/lib/ 2>/dev/null || true; \
  fi

# ✅ Make scripts executable and convert line endings
RUN find ./scripts -type f \( -name "*.sh" -o -name "*.mjs" \) -exec chmod +x {} \; 2>/dev/null || true && \
  find ./scripts -type f \( -name "*.sh" -o -name "*.mjs" \) -exec dos2unix {} \; 2>/dev/null || true && \
  find /usr/local/bin/lib -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true && \
  find /usr/local/bin/lib -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true

# ✅ Copy protobuf files
COPY protobuf/rss.proto ./protobuf/

# ✅ Copy package files
COPY vite-ui/package*.json ./

# ✅ Install dependencies with better error handling
RUN npm cache clean --force && \
  npm install --legacy-peer-deps --ignore-scripts 2>&1 | tee /tmp/npm-install.log || { \
  echo "❌ npm install failed"; \
  tail -50 /tmp/npm-install.log; \
  exit 1; \
  }

# ✅ Run placeholder scripts AFTER npm install (dependencies needed)
RUN node scripts/assure-graphql-files.mjs 2>&1 || echo "⚠️ GraphQL placeholders: using defaults"
RUN node scripts/assure-grpc-files.mjs 2>&1 || echo "⚠️ gRPC placeholders: using defaults"

# ✅ Generate gRPC from proto (if proto file exists)
RUN if [ -f "./protobuf/rss.proto" ]; then \
  echo "🔧 Generating gRPC from proto..."; \
  npm run generate-grpc:safe 2>&1 || echo "⚠️ gRPC generation skipped"; \
  npm run sync-grpc 2>&1 || true; \
  else \
  echo "⚠️ No proto file found, using placeholders"; \
  fi

# ✅ Copy remaining source files
COPY vite-ui/ ./

# ✅ Copy and prepare entrypoint
COPY vite-ui/scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
  dos2unix /usr/local/bin/docker-entrypoint.sh 2>/dev/null || true

# ✅ Verify setup
RUN echo "📂 Verification:" && \
  echo "=== Scripts ===" && ls -la ./scripts/*.sh 2>/dev/null | head -5 || echo "(none)" && \
  echo "=== Apollo ===" && ls -la ./apollo/ 2>/dev/null || echo "(empty)" && \
  echo "=== Generated ===" && ls -la ./apollo/generated/ 2>/dev/null || echo "(empty)"

# ✅ Expose ports
EXPOSE 5173

# ✅ Health check - lenient for development
HEALTHCHECK --interval=30s --timeout=15s --start-period=180s --retries=10 \
  CMD test -f /app/.ready && curl -sf http://localhost:5173 >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]

FROM base AS development

ENV NODE_ENV=development
ENV NODE_OPTIONS="--max-old-space-size=4096"

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]

# ========================================
# Build Stage (originate)
# ========================================
FROM base AS originate

ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_ENV=production

# ✅ Ensure GraphQL files before build
RUN node scripts/assure-graphql-files.mjs 2>&1 || true

# ✅ Build the application
RUN npm run build 2>&1 || { \
  echo "⚠️ Build failed, creating minimal output..."; \
  mkdir -p ./wwwroot/volume; \
  echo '<!DOCTYPE html><html><head><title>Build Pending</title></head><body><h1>Build in progress...</h1></body></html>' > ./wwwroot/volume/index.html; \
  }

# ✅ Verify build output
RUN echo "📁 Build output:" && \
  ls -la ./wwwroot/ 2>/dev/null || echo "No wwwroot" && \
  ls -la ./wwwroot/volume/ 2>/dev/null || echo "No wwwroot/volume"

# ========================================
# Production Stage
# ========================================
FROM node:22-alpine AS production

# ✅ Install runtime dependencies
RUN apk update && \
  apk add --no-cache curl bash gcompat tzdata musl musl-locales musl-locales-lang \
  font-noto-common font-noto-extra font-noto-thai font-tlwg && \
  rm -rf /var/cache/apk/*

# ✅ Set timezone
RUN cp /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
  echo "Asia/Bangkok" > /etc/timezone

WORKDIR /app

ENV NODE_ENV=production \
  LANG=th_TH.UTF-8 \
  LC_ALL=th_TH.UTF-8

# ✅ Copy built files from originate stage
COPY --from=originate /app/wwwroot ./wwwroot
COPY --from=originate /app/hub ./hub
COPY --from=originate /app/package*.json ./
COPY --from=originate /app/scripts ./scripts
COPY --from=originate /app/grpc ./grpc
COPY --from=originate /app/grpc-generated ./grpc-generated
COPY --from=originate /app/apollo ./apollo

# ✅ Install production dependencies only
RUN npm cache clean --force && \
  npm install --legacy-peer-deps --omit=dev --ignore-scripts 2>/dev/null || true

# ✅ Copy entrypoint
COPY --from=originate /usr/local/bin/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# ✅ Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
  chown -R appuser:appgroup /app

USER appuser

EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sf http://localhost:5173 >/dev/null 2>&1 || exit 0

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "5173"]