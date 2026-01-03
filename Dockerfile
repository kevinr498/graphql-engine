# syntax=docker/dockerfile:1.6

FROM debian:bookworm-slim

ARG TARGETARCH

# Runtime deps ONLY (small + fast)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libpq5 \
    libodbc1 \
    libnuma1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /hasura

# Copy correct binary based on architecture
# docker buildx sets TARGETARCH to: amd64 | arm64
COPY graphql-engine-${TARGETARCH} /bin/graphql-engine
RUN chmod +x /bin/graphql-engine

# Copy console assets
COPY frontend/dist/apps/server-assets-console-ce /hasura/console

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s \
  CMD curl -fs http://localhost:8080/healthz || exit 1

CMD ["/bin/graphql-engine", "serve", "--console-assets-dir", "/hasura/console", "--server-port", "8080"]
