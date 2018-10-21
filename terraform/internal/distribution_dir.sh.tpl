#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

# 'rules_k8s' needs to have PYTHON_RUNFILES set
export PYTHON_RUNFILES=${PYTHON_RUNFILES:=$0.runfiles}
RUNFILES=${BASH_SOURCE[0]}.runfiles
WORKSPACE_NAME="%{workspace_name}"
SRCS_LIST_PATH=$RUNFILES/$WORKSPACE_NAME/%{srcs_list_path}
README_DESCRIPTION="%{readme_description}"
terraform_docs="$RUNFILES/tool_terraform_docs/binary"
render_tf="%{render_tf}"
publish_images="%{publish_images}"

for arg in "$@"; do case $arg in
	--tgt-dir=*)
		ARG_TGT_DIR="${arg#*=}"
		;;
	*)
		>&2 echo "Unknown option '$arg'"
		exit 1
		;;
esac done

: ${ARG_TGT_DIR?"Missing Required argument --tgt-dir"}



put-file(){
	local filename=$1; shift
	local content="$(cat)"
	local temp_file=$(mktemp)
	echo "$content" > "$temp_file"
	# Error if the destination file already exists & it's NOT the same content
	if [ -e "$filename" ]; then
		local filediff=$(diff "$filename" "$temp_file")
		if [ -n "$filediff" ]; then
			2>&1 echo "ERROR, duplicate files; $filename already exists & is different: $filediff"
			exit 1
		fi
	fi
	mkdir -p $(dirname "$filename")
	mv -T "$temp_file" "$filename"
	chmod +w "$filename"
}


generate-changelog(){
	local output_dir=$1; shift
	# change dir to the repo root
	pushd $(cd "$BUILD_WORKSPACE_DIRECTORY" && git rev-parse --show-toplevel) > /dev/null

	# get the remote's URL (in order of precedence)
	local remote_url
	if remote_url=$(git remote get-url upstream 2>/dev/null); then
		:
	elif remote_url=$(git remote get-url origin 2>/dev/null); then
		:
	else
		remote_url=$(git remote get-url $(git remote))
	fi

	# "normalize" the remote URL for easier parsing of its components
	case "$remote_url" in
	# https://github.com/ceason/rules_terraform.git
	https://*) remote_url=${remote_url#https://*} ;;
	http://*)  remote_url=${remote_url#http://*} ;;

	# ssh://git@bitbucket.org/ceason/rules_terraform.git
	ssh://git@*) remote_url=${remote_url#ssh://git@*} ;;

	# git@github.com:ceason/rules_terraform.git
	git@*) remote_url=${remote_url#git@*} ;;
	*)
		>&2 echo "Unrecognized format for git remote url '$remote_url'"
		exit 1
		;;
	esac

	# parse the components of the remote
	remote_url=${remote_url%.git}
	remote_host=$(   awk -F'[:/]' '{print $1}' <<< "$remote_url")
	remote_account=$(awk -F'[:/]' '{print $2}' <<< "$remote_url")
	remote_repo=$(   awk -F'[:/]' '{print $3}' <<< "$remote_url")

	local commit_link_prefix="https://$remote_host/$remote_account/$remote_repo/commit"

	# find all commits relevant to the source files
	local filtered_commits=$(mktemp)
	local filtered_commits_unique=$(mktemp)
	local output_file=$output_dir/CHANGELOG.md
	while read filename; do
		git log --pretty='%H' --follow -- "$filename" >> "$filtered_commits"
	done < <(grep '^//' "$SRCS_LIST_PATH"|sed 's,^//,,g; s,:,/,g')
	sort -u --output="$filtered_commits_unique" "$filtered_commits"

	# create an ordered changelog, including only the filtered commits
	while read commit; do
		if grep -q $commit $filtered_commits_unique; then
			git show -s --date=short --format="- _%cd_ [\`%h\`]($commit_link_prefix/%H) %s" $commit >> "$output_file"
		fi
	done < <(git log --pretty='%H')
	rm -rf $filtered_commits
	rm -rf $filtered_commits_unique
	popd > /dev/null
}

generate-readme(){
	local output_dir=$1; shift
	# change dir to the repo root
	pushd "$output_dir" > /dev/null

	# get terraform inputs/outputs (if there are any)
	local terraform_info=$("$terraform_docs" md .)
	local terraform_section=""
	if [ -n "$terraform_info" ]; then
		terraform_section="# Terraform

$terraform_info
"
	fi

	# write the readme
	cat <<EOF |put-file "$output_dir/README.md"
$README_DESCRIPTION

$terraform_section

# Latest Changes
> For full changelog see [CHANGELOG.md](CHANGELOG.md)
EOF
	popd > /dev/null
}


main(){
	# build up the new release dir in a separate location
	local STAGING_DIR=$(mktemp -d)

	$render_tf --output_dir "$STAGING_DIR" --plugin_dir "$STAGING_DIR/terraform.d/plugins"
	generate-changelog "$STAGING_DIR"
	generate-readme "$STAGING_DIR"

	"$publish_images"

	# replace the target dir with the successfully populated staging dir
	mkdir -p "$ARG_TGT_DIR"
	chmod -R +w "$ARG_TGT_DIR"
	rm -rf "$ARG_TGT_DIR"
	mkdir -p $(dirname "$ARG_TGT_DIR")
	mv "$STAGING_DIR" "$ARG_TGT_DIR"
	chmod -R +rw "$ARG_TGT_DIR"

	# Add this stuff to git
	(cd "$ARG_TGT_DIR" && git add .)
}


main "$@"