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

for t in "${PREPUBLISH_BUILDS[@]}"; do
	>&2 echo "Building $t"
    _bazel build $t
done
for t in "${PREPUBLISH_TESTS[@]}"; do
	>&2 echo "Testing $t"
    _bazel test $t
done

# create all of the releasefiles update scripts (without running them),
# then run them in parallel

distdir_scripts=()
trap 'for f in ${distdir_scripts[@]}; do rm -rf $f; done' EXIT
for t in "${DISTRIB_DIR_TARGETS[@]}"; do
	script=$(mktemp)
	distdir_scripts+=("$script")
	ITS_A_TRAP+=("rm -rf '$script'")
	cmdout=$(mktemp)
	if env "${RELEASE_VARS[@]}" bazel run --script_path=$script "$t" > "$cmdout" 2>&1; then
		rm -rf "$cmdout"
	else
		rc=$?
		>&2 cat "$cmdout"
		rm -rf "$cmdout"
		exit $rc
	fi
done

>&2 echo "Updating release directory"
for script in "${distdir_scripts[@]}"; do
    $script &
done
wait

exit 1

# Prompt user to publish changes if there are any
if git diff --quiet -w --cached; then
	echo "There are no changes to the release files"
else
	git status
	while read -r -p "Would you like to publish these changes? [y]es|[n]o: "; do
	  case ${REPLY,,} in
		y|yes)
			git commit -m "Updating release dir"
			git push
			break
			;;
		n|no) echo "Exiting without updating releasefiles"; break;;
		*) echo "Invalid option '$REPLY'";;
	  esac
	done
fi


