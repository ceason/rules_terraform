#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

HUB_ARGS=(%{hub_args})
PREPUBLISH_TESTS=(%{prepublish_tests})
PREPUBLISH_BUILDS=(%{prepublish_builds})
VERSION="%{version}"
BRANCH="%{branch}"
PUBLISH_ENV=(%{env})
hub="$PWD/%{tool_hub}"
PRERELEASE_IDENTIFIER="rc"
BAZELRC_CONFIG="%{bazelrc_config}"

bazelcfg=""
if [ -n "$BAZELRC_CONFIG" ]; then
	bazelcfg="--config=$BAZELRC_CONFIG"
fi

_bazel(){
	# return code 4 means no tests found, so it's "successful"
	local rc=0;
	if bazel "$@"; then rc=0; else rc=$?; fi
	case "$rc" in
	0|4) ;;
	*) exit $rc ;;
	esac
}
_git(){
	local cmdout=$(mktemp)
	if git "$@" > "$cmdout" 2>&1; then
		rm -rf "$cmdout"
	else
		rc=$?
		>&2 cat "$cmdout"
		rm -rf "$cmdout"
		exit $rc
	fi
}

# Parses provided semver eg "v1.0.2-rc.1+1539276024" to:
# - SEMVER_MAJOR       1
# - SEMVER_MINOR       0
# - SEMVER_PATCH       2
# - SEMVER_PRE         rc
# - SEMVER_PRE_VERSION 1
# - SEMVER_BUILDINFO   1539276024
parse_semver(){
	local version=${1-$(cat)}
	SEMVER_BUILDINFO=$(awk -F'+' '{print $2}' <<< "$version")
	version=$(awk -F'+' '{print $1}' <<< "$version")
	SEMVER_PRE=$(awk -F'-' '{print $2}' <<< "$version")
	SEMVER_PRE_VERSION=$(awk -F'.' '{print $2}' <<< "$SEMVER_PRE")
	SEMVER_PRE=$(awk -F'.' '{print $1}' <<< "$SEMVER_PRE")
	version=$(awk -F'-' '{print $1}' <<< "$version")
	SEMVER_MAJOR=$(awk -F'.' '{print $1}' <<< "$version")
	SEMVER_MAJOR=${SEMVER_MAJOR#v*}
	SEMVER_MINOR=$(awk -F'.' '{print $2}' <<< "$version")
	SEMVER_PATCH=$(awk -F'.' '{print $3}' <<< "$version")
}

# Print out a new semver tag to use
# Tag format is "v$VERSION.$((highest_released_patch++))-rc.$((latest_rc++))"
#
# $1    - Current version
# STDIN - List of existing versions (eg 'git tag' or 'hub release')
next_prerelease(){
	local existing="$(sort --version-sort --reverse)"
	parse_semver "$1"
	local current_major=$SEMVER_MAJOR
	local current_minor=$SEMVER_MINOR
	# figure out next patch version for our major+minor ("latest published + 1")
	local next_patch_version=0
	while read v; do
	    parse_semver "$v"
	    if [ -z "$SEMVER_PRE" ]; then
	    	next_patch_version=$((${SEMVER_PATCH:-"-1"} + 1))
			break
	    fi
	done < <(grep "^[v]$current_major\.$current_minor\." <<< "$existing")

	# figure out the next prerelease version for our major+minor+next_patch
	parse_semver "$(grep "^[v]$current_major\.$current_minor\.$next_patch_version-$PRERELEASE_IDENTIFIER\." <<< "$existing" | head -1)"
	local next_pre_version=$((${SEMVER_PRE_VERSION:-"-1"} + 1))

	echo -n "v$current_major.$current_minor.$next_patch_version-$PRERELEASE_IDENTIFIER.$next_pre_version"
}

pushd "$BUILD_WORKSPACE_DIRECTORY" > /dev/null

if [ ${#PREPUBLISH_BUILDS[@]} -gt 0 ]; then
	>&2 echo "Building: $(printf "\n  %s" "${PREPUBLISH_BUILDS[@]}")"
	_bazel build -- "${PREPUBLISH_BUILDS[@]}"
fi

if [ ${#PREPUBLISH_TESTS[@]} -gt 0 ]; then
	>&2 echo "Testing: $(printf "\n  %s" "${PREPUBLISH_TESTS[@]}")"
	_bazel test -- "${PREPUBLISH_TESTS[@]}"
fi

# todo: make sure all build-relevant files are committed
# - enumerate build-relevant files & check that current content == HEAD content
# - 'git add' as necessary & prompt user to commit index

# make sure current commit exists in upstream branch
_git push
commit=$(git rev-parse --verify HEAD)

# open in browser if run from terminal
if [ -t 1 ]; then
	HUB_ARGS+=("--browse")
fi

_git fetch --tags
tag=$(git tag|next_prerelease "$VERSION")

release_message=$(mktemp)
trap "rm -rf $release_message" EXIT

# find the published tag previous to our new tag
current_tags=($(
	parse_semver $VERSION
	(git tag|grep -E "^[v]?[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$"
	 echo "$tag"
	)\
	|sort --version-sort --reverse))

current_published_tag=""
if [ "${#current_tags[@]}" -gt 1 ]; then
	current_published_tag=$(
		printf "%s\n" "${current_tags[@]}"\
		|grep -FA1 "$tag"\
		|grep -vF "$tag"
	)
fi

repo_url=$("$hub" browse -u)
echo "$tag" > "$release_message"
if [ -n "$current_published_tag" ]; then
	echo "
### Changes Since \`$current_published_tag\`:
" >> "$release_message"
	git log --format="- [\`%h\`]($repo_url/commit/%H) %s" "$current_published_tag".."$commit" >> "$release_message"
fi

"$hub" release create "${HUB_ARGS[@]}" --commitish="$commit" --file="$release_message" "$tag"
_git fetch --tags
