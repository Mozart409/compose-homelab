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
