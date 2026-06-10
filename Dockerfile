# syntax=docker/dockerfile:1

# ---- Stage 1: build the React dashboard ----
FROM node:20-alpine AS web-builder
WORKDIR /web

# Install deps first to leverage layer caching.
COPY web/package.json web/package-lock.json* ./
RUN npm ci

# Build the frontend.
COPY web/ ./
RUN npm run build

# ---- Stage 2: build the Go binary ----
FROM golang:1.26-alpine AS go-builder
WORKDIR /src

# Cache Go modules.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source.
COPY . .

# Replace the committed embed assets with the freshly built dashboard so the
# binary always embeds the matching frontend (see internal/web/embed.go).
RUN rm -rf internal/web/dist
COPY --from=web-builder /web/dist ./internal/web/dist

# Static, stripped binary for a minimal runtime image.
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0
RUN GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} \
    go build -ldflags="-s -w" -o /out/notion-manager ./cmd/notion-manager

# ---- Stage 3: minimal runtime ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -u 10001 app
WORKDIR /app

COPY --from=go-builder /out/notion-manager /usr/local/bin/notion-manager

# config.yaml, accounts/*.json and stats files are written to the working dir
# at runtime, so persist /app via a volume.
RUN mkdir -p /app/accounts && chown -R app:app /app
USER app
VOLUME ["/app"]

# Default listen port (no config.yaml -> 8081). Override via config.yaml or PORT.
EXPOSE 8081
ENV PORT=8081

ENTRYPOINT ["notion-manager"]
