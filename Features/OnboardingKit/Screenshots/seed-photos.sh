#!/usr/bin/env bash
# Local only: run after `bun run seed:local` in cloud/apps/api.
set -euo pipefail

cd "$(dirname "$0")/photos"
sql=""
while IFS=$'\t' read -r file width height thumbhash; do
    spot="${file%.*}"
    sql+="insert into spot_photo (id, spot_id, r2_key, width, height, thumbhash, has_permission, position)
values ('screenshot-$spot', '$spot', 'screenshots/$file', $width, $height, '$thumbhash', true, 0)
on conflict (spot_id, position) do update set id = excluded.id, r2_key = excluded.r2_key, width = excluded.width,
  height = excluded.height, thumbhash = excluded.thumbhash;
"
done < photos.tsv
docker exec -i openskatemap-db-1 psql -v ON_ERROR_STOP=1 -q -U openskatemap_app -d openskatemap <<< "$sql"
echo "Gave $(grep -c . photos.tsv) spots their photos."
