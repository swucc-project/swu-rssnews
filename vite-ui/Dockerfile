FROM node:22-bookworm AS base

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  git curl wget build-essential python3 task-thai locales tzdata \
  protobuf-compiler libprotobuf-dev libprotoc-dev grpc-proto protobuf-compiler-grpc libgrpc++-dev libgrpc-dev && \
  rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
  echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen th_TH.UTF-8 && \
  update-locale LANG=th_TH.UTF-8

RUN ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
  echo "Asia/Bangkok" >> /etc/timezone

ENV LANG=th_TH.UTF-8
ENV TZ=Asia/Bangkok

RUN npm install -g protoc-gen-js ts-protoc-gen

RUN wget https://github.com/grpc/grpc-web/releases/download/1.5.0/protoc-gen-grpc-web-1.5.0-linux-x86_64 && \
  mv protoc-gen-grpc-web-1.5.0-linux-x86_64 /usr/local/bin/protoc-gen-grpc-web && \
  chmod +x /usr/local/bin/protoc-gen-grpc-web

RUN curl -sSL https://rover.apollo.dev/nix/latest | sh
ENV PATH="$PATH:/root/.rover/bin"

WORKDIR /app

# ========================================
# Development Stage
# ========================================
FROM base AS development

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl dos2unix build-essential task-thai locales tzdata libthai-data libthai-dev \
  net-tools netcat-openbsd jq fonts-noto-core fonts-noto-extra fonts-sipa-arundina fonts-thai-tlwg && \
  rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
  echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
  locale-gen th_TH.UTF-8 && \
  update-locale LANG=th_TH.UTF-8 && \
  ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
  echo "Asia/Bangkok" >> /etc/timezone

ENV LANG=th_TH.UTF-8
ENV TZ=Asia/Bangkok
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_ENV=development
ENV DOCKER_CONTAINER=true
ENV IS_DOCKER=true

COPY vite-ui/package*.json ./
COPY vite-ui/scripts/*.sh ./scripts/
RUN chmod +x ./scripts/*.sh

# โœ… Create directories
RUN mkdir -p \
  ./grpc \
  ./grpc-generated \
  ./apollo/generated \
  ./apollo/fragments \
  ./wwwroot/grpc \
  /app/wwwroot/volume \
  /app/node_modules/.vite

# โœ… สร้าง placeholder fragments
RUN cat > ./apollo/generated/fragments.ts <<'EOF'
import gql from 'graphql-tag';

export const RSS_ITEM_FIELDS = gql`
  fragment RssItemFields on RssItem {
    itemID
    title
    link
    description
    publishedDate
    category {
      categoryID
      categoryName
    }
    author {
      buasriID
      firstName
      lastName
    }
  }
`;

export const CATEGORY_FIELDS = gql`
  fragment CategoryFields on Category {
    categoryID
    categoryName
  }
`;

export const AUTHOR_FIELDS = gql`
  fragment AuthorFields on Author {
    buasriID
    firstName
    lastName
  }
`;

export type RssItemFieldsFragment = {
  itemID: string;
  title: string;
  link: string;
  description?: string | null;
  publishedDate: string;
  category?: {
    categoryID: number;
    categoryName: string;
  } | null;
  author?: {
    buasriID: string;
    firstName: string;
    lastName: string;
  } | null;
};
EOF

RUN echo '{"possibleTypes":{}}' > ./apollo/generated/introspection.json && \
  echo 'export const documents = {};' > ./apollo/generated/graphql.ts && \
  echo 'export type Maybe<T> = T | null;' > ./apollo/generated/index.ts

RUN cat > ./apollo/schema.graphql <<'EOF'
type Query {
  _placeholder: String
}
type Mutation {
  _placeholder: String
}
schema {
  query: Query
  mutation: Mutation
}
EOF

# โœ… ติดตั้ง dependencies ด้วย --legacy-peer-deps
RUN npm cache clean --force && \
  npm install --legacy-peer-deps && \
  npm install -g graphql-cli graphql-json-to-sdl

# โœ… Copy protobuf และ scripts
COPY protobuf/rss.proto ./protobuf/rss.proto
COPY vite-ui/scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN dos2unix /usr/local/bin/docker-entrypoint.sh

# โœ… Copy remaining files
COPY vite-ui/ ./

# โœ… Generate gRPC
RUN npm run generate-grpc || echo "โš ๏ธ gRPC generation failed (non-critical)"
RUN ./scripts/unify-grpc.sh || echo "โš ๏ธ gRPC sync failed (non-critical)"

# โœ… ให้สิทธิ์ script
RUN chmod +x ./scripts/generate-fragments.sh || true

# โœ… สร้าง user
RUN groupadd -r viteuser && \
  useradd -r -g viteuser -d /app -s /sbin/nologin viteuser && \
  chown -R viteuser:viteuser /app /app/node_modules /app/apollo /app/scripts && \
  chmod -R 755 /app/wwwroot && \
  chmod -R 775 /app/node_modules/.vite

USER viteuser

EXPOSE 5173 13714

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
  CMD curl -f http://localhost:5173 > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ========================================
# Build Stage
# ========================================
FROM base AS originate

ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_ENV=production

COPY vite-ui/package*.json ./
COPY vite-ui/scripts/ ./scripts/
RUN chmod +x ./scripts/*.sh

RUN mkdir -p ./grpc ./grpc-generated ./apollo/generated ./apollo/fragments ./wwwroot/grpc

# โœ… สร้าง placeholder fragments สำหรับ build
RUN cat > ./apollo/generated/fragments.ts <<'EOF'
import gql from 'graphql-tag';

export const RSS_ITEM_FIELDS = gql`
  fragment RssItemFields on RssItem {
    itemID
    title
    link
    description
    publishedDate
    category {
      categoryID
      categoryName
    }
    author {
      buasriID
      firstName
      lastName
    }
  }
`;

export const CATEGORY_FIELDS = gql`
  fragment CategoryFields on Category {
    categoryID
    categoryName
  }
`;

export const AUTHOR_FIELDS = gql`
  fragment AuthorFields on Author {
    buasriID
    firstName
    lastName
  }
`;
EOF

RUN echo '{"possibleTypes":{}}' > ./apollo/generated/introspection.json && \
  echo 'export const documents = {};' > ./apollo/generated/graphql.ts && \
  echo 'export type Maybe<T> = T | null;' > ./apollo/generated/index.ts

RUN cat > ./apollo/schema.graphql <<'EOF'
type Query {
  _placeholder: String
}
schema {
  query: Query
}
EOF

# โœ… ใช้ npm ci พร้อม --legacy-peer-deps
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

COPY protobuf/rss.proto ./protobuf/rss.proto
COPY vite-ui/ ./

RUN npm run generate-grpc || echo "โš ๏ธ gRPC generation skipped"
RUN ./scripts/unify-grpc.sh || echo "โš ๏ธ gRPC sync skipped"

# โœ… Build ทั้ง client และ SSR
RUN npm run build

# ========================================
# Production Stage
# ========================================
FROM node:22-alpine AS production

RUN apk add --no-cache curl dos2unix musl-locales musl-locales-lang tzdata font-noto font-noto-cjk font-tlwg net-tools netcat-openbsd && \
  echo "export LC_ALL=th_TH.UTF-8" >> /etc/profile && \
  echo "export LANG=th_TH.UTF-8"   >> /etc/profile && \
  echo "export LANGUAGE=th_TH.UTF-8" >> /etc/profile && \
  ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
  echo "Asia/Bangkok" >> /etc/timezone

ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=2048"

WORKDIR /app

COPY --from=originate /app/dist ./dist
COPY --from=originate /app/wwwroot/ssr ./wwwroot/ssr
COPY --from=originate /app/hub ./hub
COPY --from=originate /app/package*.json ./

RUN npm ci --only=production --legacy-peer-deps && \
  npm cache clean --force

RUN addgroup -S viteuser && \
  adduser -S -G viteuser viteuser && \
  chown -R viteuser:viteuser /app

USER viteuser

EXPOSE 13714

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:13714/health > /dev/null 2>&1 || exit 1

CMD ["npm", "run", "start:ssr:prod"]