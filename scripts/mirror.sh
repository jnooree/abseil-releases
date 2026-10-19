#!/bin/bash

set -euo pipefail

if [[ $# != 2 ]]; then
	echo "Usage: $0 SRC DEST" >&2
	exit 2
fi

src=$1
dest=$2
mirror=$(mktemp -d)
trap 'rm -rf "$mirror"' EXIT

git clone --mirror "$src" "$mirror/src.git"
cd "$mirror/src.git"

git ls-remote --tags --refs "$dest" >"$mirror/dest-tags"
git for-each-ref --format='%(objectname) %(refname)' refs/tags >"$mirror/src-tags"

declare -A destination_tags
while read -r object ref; do
	destination_tags[$ref]=$object
done <"$mirror/dest-tags"

new_tags=()
while read -r object ref; do
	existing=${destination_tags[$ref]-}
	if [[ -z $existing ]]; then
		new_tags+=("$ref")
	elif [[ $existing != "$object" ]]; then
		echo "Tag conflict: $ref ($existing != $object)" >&2
		exit 1
	fi
done <"$mirror/src-tags"

git push --atomic --no-mirror "$dest" \
	'+refs/heads/master:refs/heads/master' \
	'+refs/heads/lts_*:refs/heads/lts_*'

for ref in "${new_tags[@]}"; do
	git push --no-mirror "$dest" "$ref:$ref"
done
