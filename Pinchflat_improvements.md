# Pinchflat Improvements

Issues discovered while debugging Jellyfin artwork problems.

## Issue 1: Source images not downloaded for early sources

**Problem:** Sources created before `download_source_images` was added to the media profile have empty `poster_filepath`, `fanart_filepath`, and `banner_filepath` in the `sources` table. The `source_metadata` table may have stale references to files that were never actually downloaded.

**Example:** Tsoding (source id 11, created 2025-06-04)

- `sources` table has empty artwork paths
- `source_metadata` references `/config/metadata/sources/11/*.jpg` but folder doesn't exist

**Expected behavior:** When `download_source_images: true` is set on a media profile, existing sources using that profile should have their artwork downloaded on next index.

**Suggested fix:** Add a migration or background job that:

1. Checks all sources using profiles with `download_source_images: true`
2. Downloads missing source images for sources that don't have them
3. Updates both `sources` and `source_metadata` tables

## Issue 2: Source images not downloaded for some new sources

**Problem:** Some recently added sources have no `source_metadata` entry at all, even though they use a profile with `download_source_images: true`.

**Example:** Jimmy_Broadbent (source id 97, created 2026-01-13)

- No entry in `source_metadata` table
- No metadata folder at `/config/metadata/sources/97/`
- No artwork files in show folder
- 1521 media items indexed, videos were downloaded (then culled due to 3-day retention)

**Expected behavior:** Source metadata and images should be downloaded when a source is first indexed, regardless of retention settings.

**Suggested fix:**

1. Investigate why `source_metadata` entry wasn't created during initial indexing
2. Ensure source image download happens before/independently of media downloads
3. Add error logging if source image download fails

## Issue 3: No way to re-trigger source image download

**Problem:** There's no UI option or API endpoint to re-download source images for an existing source. Users must delete and re-add the source.

**Suggested fix:** Add a "Refresh source metadata" button in the source settings that:

1. Re-fetches channel metadata from YouTube
2. Downloads/updates poster, fanart, and banner images
3. Updates the `source_metadata` and `sources` tables
4. Copies images to the show folder

## Database schema reference

```sql
-- sources table (relevant columns)
SELECT id, custom_name, poster_filepath, fanart_filepath, banner_filepath FROM sources;

-- source_metadata table
SELECT source_id, metadata_filepath, fanart_filepath, poster_filepath, banner_filepath FROM source_metadata;

-- Metadata files stored in
/config/metadata/sources/{source_id}/
  - metadata.json.gz
  - poster.jpg
  - fanart.jpg
  - banner.jpg

-- Show folder should have copies
/downloads/shows/{source_custom_name}/
  - poster.jpg
  - fanart.jpg
  - banner.jpg
  - tvshow.nfo
```

## Issue 4: SQLite "Database busy" errors blocking job processing

**Problem:** The Oban job queue can get stuck with "Database busy" errors, preventing all indexing and download jobs from processing. This occurs when:

1. Long-running operations hold database locks
2. The WAL (Write-Ahead Log) file grows very large (observed 252MB)
3. Multiple concurrent operations compete for write access

**Symptoms:**

- Logs show repeated `(Exqlite.Error) Database busy` errors
- `Oban.Stager` GenServer terminates repeatedly
- Jobs stay in `available` state but never execute
- `last_indexed_at` for sources becomes very stale (months old)

**Example log:**

```
[error] | GenServer {Oban.Registry, {Oban, Oban.Stager}} terminating
** (Exqlite.Error) Database busy
UPDATE "oban_jobs" AS o0 SET "state" = ? WHERE (o0."id" IN (?))
```

**Root cause:** SQLite's `busy_timeout` PRAGMA defaults to 0 in the application, meaning queries fail immediately instead of waiting for locks to be released.

**Suggested fixes:**

1. **Set busy_timeout PRAGMA** - Configure Exqlite/Ecto to use a reasonable busy_timeout (e.g., 5000ms) so queries wait for locks instead of failing immediately
2. **Configure WAL autocheckpoint** - Ensure WAL doesn't grow unbounded; set `wal_autocheckpoint` to a reasonable value
3. **Add connection pool limits** - Limit concurrent database writers to reduce lock contention
4. **Implement job queue cleanup** - Automatically prune old completed/cancelled jobs to keep the oban_jobs table smaller

**Workaround:** Restart Pinchflat container to clear stuck state and checkpoint WAL:

```bash
docker compose restart pinchflat
```

**Manual database maintenance:**

```bash
# Stop Pinchflat first
docker compose stop pinchflat

# Clean old jobs and optimize
sqlite3 /path/to/pinchflat.db "
  DELETE FROM oban_jobs WHERE state = 'completed' AND completed_at < datetime('now', '-7 days');
  DELETE FROM oban_jobs WHERE state = 'cancelled' AND scheduled_at < datetime('now', '-7 days');
  ANALYZE;
  VACUUM;
"

# Start Pinchflat
docker compose start pinchflat
```

## Issue 5: Orphaned deletion jobs for non-existent sources

**Problem:** When a source is deleted, a `SourceDeletionWorker` job is created. If this job fails repeatedly (e.g., due to database busy errors or files already deleted), it keeps retrying indefinitely even after the source no longer exists.

**Example:** Source ID 97 was deleted, but the deletion job kept retrying (14 attempts) even though there was nothing left to delete.

**Suggested fix:**

1. Add a check at the start of `SourceDeletionWorker` to verify the source still exists
2. If source doesn't exist, mark job as completed (or cancelled) instead of retrying
3. Consider adding idempotency - if files/records are already gone, succeed gracefully

## Issue 6: Sources with `last_indexed_at = NULL` never get indexed

**Problem:** Some sources show `last_indexed_at` as NULL in the database, indicating they were never successfully indexed. These sources have indexing jobs in the queue but the jobs may have failed silently or been stuck.

**Example sources with NULL `last_indexed_at`:**

- PietSmietTV (id 91)
- Rory Alexander (id 93)
- BigfryTV (id 94)
- Multiple sources added on 2026-03-06 (ids 101-118)

**Suggested fix:**

1. Add monitoring/alerting for sources that haven't been indexed within expected timeframe
2. Add a "Force re-index" button in the UI
3. Log more details when indexing jobs fail
4. Consider a health check that identifies sources with stale/null `last_indexed_at`
