# Agent Guidelines for compose-homelab

This document provides coding guidelines and operational instructions for AI agents working in this repository.

## Project Overview

This is a Docker Compose-based homelab stack that runs various services (Jellyfin, SearXNG, Pinchflat, Tandoor, etc.) proxied through Tailscale Serve. All services are containerized and managed via Docker Compose.

**Production System**: The production environment is accessible via `ssh root@homelab`

## Build, Lint, and Test Commands

### Primary Commands (using just)

```bash
# Start all services (default command)
just up              # Pulls git, builds and starts all services

# Stop all services
just down

# Restart services
just restart

# Pull latest images
just pull

# Format configuration files
just fmt             # Runs dprint formatter

# Clear terminal
just clear
```

### Direct Docker Compose Commands

```bash
# Start services
docker compose up -d --build --remove-orphans

# Stop services
docker compose down

# View logs for a specific service
docker compose logs -f <service-name>

# View logs for a single service (e.g., jellyfin)
docker compose logs -f jellyfin

# Restart a single service
docker compose restart <service-name>

# Pull latest images
docker compose pull

# Check service status
docker compose ps

# Execute command in running container
docker compose exec <service-name> <command>
```

### Formatting

```bash
# Format all files (YAML, JSON, Markdown, TOML, Dockerfile)
dprint fmt

# Check formatting without making changes
dprint check

# Format specific files
dprint fmt <file-path>
```

## Code Style and Guidelines

### File Formatting

- **Formatter**: dprint is used for all configuration files
- **Pre-commit Hook**: lefthook runs `dprint fmt` on staged files automatically
- **Supported formats**: TypeScript, JSON, Markdown, TOML, Dockerfile, CSS, HTML, YAML

### Docker Compose Style

#### Service Structure

```yaml
service-name:
  image: registry/image:version # Use pinned versions with semantic versioning
  container_name: service-name # Always specify container name
  restart: unless-stopped # Default restart policy
  stop_grace_period: 30s # Always include 30s grace period
  network_mode: service:ts-service-name # Use Tailscale sidecar pattern
  environment:
    - VAR_NAME=${ENV_VAR} # Use environment variable substitution
    - TZ=Europe/Berlin # Specify timezone when needed
  volumes:
    - ${PWD}/service:/config # Use ${PWD} for relative paths
    - ./local:/data # Or ./ for simple paths
  healthcheck: # Include healthchecks for critical services
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s
  labels: # Include WUD (What's Up Docker) labels
    - 'wud.tag.include=^\d+\.\d+\.\d+$$' # Version matching pattern
    - "wud.link.template=https://github.com/org/repo/releases/tag/$${major}.$${minor}.$${patch}"
```

#### Version Pinning

- **Always pin to specific versions**: Use `image:1.2.3` not `image:latest`
- **Semantic versioning**: Use major.minor.patch format
- **SHA pinning**: For images without version tags, use SHA256 digest: `image:latest@sha256:abc...`

#### Tailscale Sidecar Pattern

Services use Tailscale sidecars for networking:

```yaml
# Application service
service:
  network_mode: service:ts-service
  depends_on:
    - ts-service

# Tailscale sidecar
ts-service:
  image: tailscale/tailscale:v1.94.2
  container_name: ts-service
  hostname: service
  cap_add:
    - net_admin
    - sys_module
  devices:
    - /dev/net/tun:/dev/net/tun
  dns:
    - 100.100.100.100 # Tailnet lookups
    - 1.1.1.1 # External lookups
  environment:
    - "TS_AUTHKEY=${TS_AUTH_KEY}"
    - "TS_SERVE_CONFIG=/config/service.json"
    - "TS_STATE_DIR=/var/lib/tailscale"
    - "TS_USERSPACE=false"
  volumes:
    - ${PWD}/tailscale-service-data/state:/var/lib/tailscale
    - ${PWD}/config:/config
  restart: unless-stopped
  stop_grace_period: 30s
```

### Environment Variables

- **Required vars**: Store in `.env` file (git-ignored)
- **Example template**: See `.env.example` for required variables
- **Key variables**:
  - `TS_AUTH_KEY`: Tailscale authentication key
  - `OPENAI_API_KEY`: OpenAI API access
  - Service-specific OAuth credentials

### Naming Conventions

- **Services**: Use lowercase with hyphens (e.g., `node-exporter`, `ts-jellyfin`)
- **Container names**: Match service name or use descriptive name
- **Volumes**: Use descriptive names with underscores (e.g., `tandoor_pg_data`)
- **Files**: Use lowercase with hyphens or underscores

### Git Commit Style

Follow Conventional Commits with optional gitmoji:

```
feat: add new service to compose stack
fix: correct healthcheck for jellyfin
docs: update README with new service
feat: :arrow_up: upgrade package versions
fix(wud): correct version matching labels
```

**Patterns**:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation only
- `feat(scope):` - Feature with scope
- Optional gitmoji: `:arrow_up:` for upgrades, `:memo:` for docs

### Error Handling

- **Healthchecks**: Always include for critical services
- **Grace periods**: 30s `stop_grace_period` for clean shutdowns
- **Restart policy**: Use `unless-stopped` for all services
- **Dependencies**: Use `depends_on` with conditions when needed

## Configuration Files

### Tailscale Serve Configs

Located in `config/` directory. Example structure:

```json
{
  "TCP": {
    "443": {
      "HTTPS": true
    }
  },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": {
          "Proxy": "http://127.0.0.1:8080"
        }
      }
    }
  },
  "AllowFunnel": {
    "${TS_CERT_DOMAIN}:443": false
  }
}
```

## Best Practices

1. **Always pin versions**: Never use `latest` tags without SHA
2. **Include healthchecks**: For all user-facing services
3. **Set resource limits**: Use `mem_limit` for resource-intensive services (see netalertx)
4. **Use read-only when possible**: Add `read_only: true` for security
5. **Drop capabilities**: Use `cap_drop: [ALL]` and only add required caps
6. **Format before commit**: Pre-commit hook runs automatically
7. **Document environment vars**: Add new vars to `.env.example`
8. **Test locally first**: Run `just up` before pushing
9. **Check logs**: Use `docker compose logs -f <service>` to verify

## Deployment Workflow

1. Make changes locally
2. Format: `just fmt` or rely on pre-commit hook
3. Test locally: `just up`
4. Check logs: `docker compose logs -f <service>`
5. Commit with conventional commit message
6. Push: `./push.sh` (pushes to origin and codeberg)
7. Deploy to production: SSH to homelab and pull changes

## Common Issues

- **Service won't start**: Check logs with `docker compose logs <service>`
- **Networking issues**: Verify Tailscale sidecar is running
- **Permission errors**: Check volume mount permissions (some services run as root)
- **Format failures**: Run `dprint fmt` manually to see specific errors

### Jellyfin Phantom/Orphan Entries

Jellyfin can show "phantom" entries in the frontend for media files that have been deleted from the filesystem. This is a known Jellyfin bug where the library cleanup tasks fail to remove orphaned database entries.

**Why orphans occur:**

- Files deleted externally (by Pinchflat, Syncthing, or manual deletion) while Jellyfin is running
- Library scan adds new items but is conservative about removing entries
- Race conditions during scans or metadata fetches
- Real-time monitoring (inotify) doesn't always catch deletions

**Solution - Direct database cleanup:**

```bash
# 1. Stop Jellyfin
ssh root@homelab "cd /root/compose-homelab && docker compose stop jellyfin"

# 2. Find orphaned entries (check paths that don't exist on filesystem)
ssh root@homelab 'sqlite3 /root/compose-homelab/jellyfin/library/data/data/jellyfin.db "SELECT Name, Path FROM BaseItems WHERE Path LIKE '\''/data/youtube/shows/ShowName%'\''"'

# 3. Delete orphaned entries
ssh root@homelab "sqlite3 /root/compose-homelab/jellyfin/library/data/data/jellyfin.db \"DELETE FROM BaseItems WHERE Path LIKE '/data/youtube/shows/ShowName%'\""

# 4. Restart Jellyfin
ssh root@homelab "cd /root/compose-homelab && docker compose start jellyfin"
```

**Important notes:**

- `jellyfin.db` contains ALL data: library items, user accounts, watch history, playback positions
- Deleting from `BaseItems` table removes library entries but preserves user data
- The old `library.db` file no longer exists in newer Jellyfin versions (merged into `jellyfin.db`)
- Clearing `cache/` and `data/metadata/` folders alone will NOT fix phantom entries
- After database changes, hard-refresh browser (Ctrl+Shift+R) to clear frontend cache

**Path mappings (container -> host):**

- `/data/youtube` -> `/root/compose-homelab/youtube`
- `/data/blueray` -> `/root/compose-homelab/blueray`
- `/data/my_movies` -> `/root/compose-homelab/movies`
- `/data/series` -> `/root/compose-homelab/series`
- `/data/tv` -> `/root/compose-homelab/tv`

### Pinchflat Source Management

Pinchflat is a YouTube media downloader. The API requires session cookies with CSRF tokens for authentication.

**Database location:** `/root/compose-homelab/pinchflat/config/db/pinchflat.db`

**Key tables:**

- `sources` - YouTube channels/playlists to download
- `media_items` - Individual videos
- `oban_jobs` - Background job queue (deletions, indexing, downloads)

#### Deleting Sources

Sources must be deleted via API (not directly in database) to trigger background cleanup jobs.

```bash
# Delete a source by ID (with file deletion)
BASE_URL="http://192.168.2.100:8945"

# Get session cookie and CSRF token
curl -c /tmp/pf_cookies.txt -s "$BASE_URL/sources" > /tmp/pf_page.html
CSRF=$(grep -oP 'csrf-token" content="\K[^"]+' /tmp/pf_page.html)

# Delete source (returns 302 on success)
curl -b /tmp/pf_cookies.txt -X DELETE "$BASE_URL/sources/SOURCE_ID?delete_files=true" \
  -H "x-csrf-token: $CSRF"
```

#### Adding Sources

Sources are added via POST to `/sources` with form data.

```bash
BASE_URL="http://192.168.2.100:8945"

# Get session cookie and CSRF token
curl -c /tmp/pf_cookies.txt -s "$BASE_URL/sources/new" > /tmp/pf_page.html
CSRF=$(grep -oP 'csrf-token" content="\K[^"]+' /tmp/pf_page.html)

# Create source (returns 302 on success)
curl -b /tmp/pf_cookies.txt -X POST "$BASE_URL/sources" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "_csrf_token=${CSRF}" \
  -d "source[original_url]=https://www.youtube.com/@ChannelName/videos" \
  -d "source[custom_name]=Channel Name" \
  -d "source[media_profile_id]=1" \
  -d "source[index_frequency_minutes]=360" \
  -d "source[download_media]=true" \
  -d "source[download_cutoff_date]=2026-03-01" \
  -d "source[retention_period_days]=5" \
  -d "source[fast_index]=false" \
  -d "source[cookie_behaviour]=disabled"
```

**Index frequency options:**

| Value | Frequency                    |
| ----- | ---------------------------- |
| -1    | Only once when first created |
| 30    | 30 minutes                   |
| 60    | 1 Hour                       |
| 180   | 3 Hours                      |
| 360   | 6 Hours                      |
| 720   | 12 Hours                     |
| 1440  | Daily (default)              |
| 10080 | Weekly                       |
| 43200 | Monthly                      |

#### Listing Sources

```bash
ssh root@homelab "sqlite3 -header -column /root/compose-homelab/pinchflat/config/db/pinchflat.db \
  'SELECT id, custom_name, original_url, retention_period_days FROM sources ORDER BY id'"
```

#### Database Maintenance

```bash
# Vacuum database to reclaim space after deletions
ssh root@homelab "sqlite3 /root/compose-homelab/pinchflat/config/db/pinchflat.db 'VACUUM;'"

# Check background job status
ssh root@homelab "sqlite3 -header -column /root/compose-homelab/pinchflat/config/db/pinchflat.db \
  'SELECT state, worker, COUNT(*) FROM oban_jobs GROUP BY state, worker ORDER BY state'"

# If Oban jobs stop running with "Database busy" errors
# 1) Clear WAL + vacuum (safe):
ssh root@homelab "sqlite3 /root/compose-homelab/pinchflat/config/db/pinchflat.db 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'"

# 2) Requeue stuck executing jobs (replace IDs after listing):
ssh root@homelab "sqlite3 -header -column /root/compose-homelab/pinchflat/config/db/pinchflat.db \
  'SELECT id, worker, attempt, inserted_at FROM oban_jobs WHERE state=\'executing\''"
ssh root@homelab "sqlite3 /root/compose-homelab/pinchflat/config/db/pinchflat.db \
  \"UPDATE oban_jobs SET state='available', scheduled_at=datetime('now'), attempted_at=NULL WHERE id IN (<ids>);\""

# 3) Restart service and watch counts drain:
ssh root@homelab "cd /root/compose-homelab && docker compose restart pinchflat"
ssh root@homelab "sqlite3 -header -column /root/compose-homelab/pinchflat/config/db/pinchflat.db \
  'SELECT state, worker, COUNT(*) FROM oban_jobs GROUP BY state, worker ORDER BY state'"

# Note: If this recurs often, consider moving Pinchflat off SQLite to Postgres.
```

### tsbridge (Tailscale Reverse Proxy)

tsbridge is a tsnet-powered reverse proxy that exposes Docker services on the Tailnet via container labels — replacing per-service Tailscale sidecars.

**Docs:**

- Repository: https://github.com/jtdowney/tsbridge
- Docker labels reference: https://github.com/jtdowney/tsbridge/blob/main/docs/docker-labels.md
- Configuration reference: https://github.com/jtdowney/tsbridge/blob/main/docs/configuration-reference.md

**How it works:**

1. tsbridge runs with `--provider docker` and watches the Docker socket for label changes
2. Containers with `tsbridge.enabled=true` are automatically proxied onto the tailnet
3. Each service gets its own hostname: `https://<name>.<tailnet>.ts.net`
4. Requires Tailscale OAuth credentials (not auth keys)

**tsbridge container labels (on the tsbridge service itself):**

```yaml
labels:
  - "tsbridge.tailscale.oauth_client_id_env=TS_OAUTH_CLIENT_ID"
  - "tsbridge.tailscale.oauth_client_secret_env=TS_OAUTH_CLIENT_SECRET"
  - "tsbridge.tailscale.state_dir=/var/lib/tsbridge"
  - "tsbridge.tailscale.default_tags=tag:server" # optional, must match OAuth client tag
  - "tsbridge.tailscale.oauth_preauthorized=false" # optional, default true
  - "tsbridge.global.metrics_addr=:9090" # optional
  - "tsbridge.global.write_timeout=30s" # optional
```

**Service container labels:**

```yaml
labels:
  # Required
  - "tsbridge.enabled=true"
  - "tsbridge.service.port=8080" # recommended over backend_addr

  # Optional
  - "tsbridge.service.name=custom-name" # default: container name
  - "tsbridge.service.backend_addr=myservice:8080" # alternative to port
  - "tsbridge.service.whois_enabled=true" # add Tailscale-User-* headers
  - "tsbridge.service.tags=tag:api" # override default_tags
  - "tsbridge.service.listen_addr=0.0.0.0:9090" # custom listen address
  - "tsbridge.service.insecure_skip_verify=true" # skip TLS verify for HTTPS backends

  # SSE / streaming (required for long-lived connections)
  - "tsbridge.service.write_timeout=0s"
  - "tsbridge.service.flush_interval=-1ms"

  # Custom headers
  - "tsbridge.service.downstream_headers.X-Frame-Options=DENY"
  - "tsbridge.service.upstream_headers.X-Service-Name=api"
  - "tsbridge.service.remove_downstream=Server,X-Powered-By"
```

**Key notes:**

- Use `port` not `backend_addr` with `localhost` — localhost inside tsbridge is the tsbridge container, not your service
- Labels are only read at container start — restart the service container to apply changes
- All containers must share a Docker network (automatic in a single compose file)
- OAuth credentials are set up at https://login.tailscale.com/admin/settings/oauth

**Migrating from Tailscale sidecars:**

1. Remove the `ts-<service>` sidecar container
2. Remove `network_mode: service:ts-<service>` and `depends_on: ts-<service>` from the app
3. Add tsbridge labels to the app container
4. Remove the sidecar's Tailscale serve config JSON from `config/`
5. Remove the sidecar's state volume

## Additional Notes

- **Nix support**: Project includes `flake.nix` for Nix development shell
- **Git hooks**: lefthook manages pre-commit formatting
- **Multiple remotes**: Pushes to both GitHub (origin) and Codeberg
