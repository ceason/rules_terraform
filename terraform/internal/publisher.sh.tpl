#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

# register cleanup traps here, then execute them on EXIT!
ITS_A_TRAP=()
cleanup(){
	set +e # we want to keep executing cleanup hooks even if one fails
	local JOBS="$(jobs -rp)"
    if [ -n "${JOBS}" ]; then
       kill $JOBS
       wait $JOBS 2>/dev/null
    fi
    # walk the hooks in reverse order (run most recently registered first)
    for (( idx=${#ITS_A_TRAP[@]}-1 ; idx>=0 ; idx-- )) ; do
		local cmd="${ITS_A_TRAP[idx]}"
		(eval "$cmd")
	done
}
trap cleanup EXIT

export RUNFILES=${RUNFILES:=$0.runfiles}
export PYTHON_RUNFILES=${PYTHON_RUNFILES:=$0.runfiles}
RELEASE_VARS=(%{env_vars})
PREPUBLISH_TESTS=(%{prepublish_tests})
PREPUBLISH_BUILDS=(%{prepublish_builds})
DISTRIB_DIR_TARGETS=(%{distrib_dir_targets})
REMOTE="%{remote}"
REMOTE_PATH="%{remote_path}"
REMOTE_BRANCH="%{remote_branch}"
BAZELRC_CONFIG="%{bazelrc_config}"

bazelcfg=""
if [ -n "$BAZELRC_CONFIG" ]; then
	bazelcfg="--config=$BAZELRC_CONFIG"
fi

cd "$BUILD_WORKSPACE_DIRECTORY"


# This script will...
# - make sure everything builds
# - run the configured tests
# - then update all releasefiles directories!
# todo: check that all targets' source files are checked in before committing/pushing the release directory

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

if [ ${#PREPUBLISH_BUILDS[@]} -gt 0 ]; then
	>&2 echo "Building: $(printf "\n  %s" "${PREPUBLISH_BUILDS[@]}")"
	_bazel build -- "${PREPUBLISH_BUILDS[@]}"
fi

if [ ${#PREPUBLISH_TESTS[@]} -gt 0 ]; then
	>&2 echo "Testing: $(printf "\n  %s" "${PREPUBLISH_TESTS[@]}")"
	_bazel test -- "${PREPUBLISH_TESTS[@]}"
fi

# create all of the releasefiles update scripts (without running them),
# then run them in parallel
distdir_scripts=()
trap 'for f in ${distdir_scripts[@]}; do rm -rf $f; done' EXIT
for item in "${DISTRIB_DIR_TARGETS[@]}"; do
	name=$(cut -d'=' -f1 <<< "$item")
	label=$(cut -d'=' -f2 <<< "$item")
	script=$(mktemp)
	distdir_scripts+=("${name}=${script}")
	ITS_A_TRAP+=("rm -rf '$script'")
	cmdout=$(mktemp)
	if env "${RELEASE_VARS[@]}" bazel run "$bazelcfg" --script_path=$script "$label" > "$cmdout" 2>&1; then
		rm -rf "$cmdout"
	else
		rc=$?
		>&2 cat "$cmdout"
		rm -rf "$cmdout"
		exit $rc
	fi
done

# figure out what the "output root" is (ie is it our own repo, or a remote one...)
OUTPUT_ROOT=$BUILD_WORKSPACE_DIRECTORY/%{package}
UPDATE_DIR_MESSAGE="Updating release directory"
if [ -n "${REMOTE:=""}" ]; then
	# if it's a remote repo, clone down to a cache dir
	sanitized_remote=$(tr '@/.:' '_' <<< "$REMOTE")
	repo_dir="$HOME/.cache/rules_terraform_publisher/$sanitized_remote/$REMOTE_BRANCH"
	if [ ! -e "$repo_dir" ]; then
		git clone $REMOTE -b "$REMOTE_BRANCH" "$repo_dir"
	else
		pushd "$repo_dir" > /dev/null
		_git reset --hard
		_git clean -fxd
		_git pull
		popd > /dev/null
	fi
	OUTPUT_ROOT=$repo_dir/$REMOTE_PATH
	UPDATE_DIR_MESSAGE="$UPDATE_DIR_MESSAGE ($REMOTE)"
fi

>&2 echo "$UPDATE_DIR_MESSAGE"
returncodes=$(mktemp -d)
ITS_A_TRAP+=("rm -rf $returncodes")
for item in "${distdir_scripts[@]}"; do
	name=$(cut -d'=' -f1 <<< "$item")
	script=$(cut -d'=' -f2 <<< "$item")
    ( set +e
      "$script" --tgt-dir="$OUTPUT_ROOT/$name"
      echo -n "$?" > "$returncodes/$BASHPID"
    ) &
done
wait
for file in "$returncodes"/*; do
	rc=$(cat "$file")
    if [ "$rc" -ne 0 ]; then
    	exit $rc
    fi
done

# Prompt user to publish changes if there are any
cd "$OUTPUT_ROOT"
cd "$(git rev-parse --show-toplevel)"
if git diff --quiet -w --cached; then
	echo "There are no changes to the release files"
else
	git status
	while read -r -p "Would you like to publish these changes?
[y]es, [n]o, show [d]iff: "; do
	  case ${REPLY,,} in
		y|yes)
			git commit -m "Updating release dir"
			git push
			break
			;;
		n|no) echo "Exiting without updating releasefiles"; break;;
		d|diff)
			git diff -w --cached
			git status
			;;
		*) echo "Invalid option '$REPLY'";;
	  esac
	done
fi


