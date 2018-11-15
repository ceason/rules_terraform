

## GH Release Sequence
#### Local Pre-flight checks
- test all `ghrelease_test_suite`s
- build all configured builds+tests
- check that all transitive (BUILD+source)files for artifacts & tests match with HEAD
  - else prompt user to commit specified files
- ?check that no '--override_repository' (use '--announce_rc' flag to see effective flags per-config?)
- add configured repo as 'upstream' remote if necessary (tracked remote is a fork & no upstream remote present)
- check that current branch is in-sync with configured repo+branch
  - else prompt user to rebase/pull

#### Remote Pre-flight checks
- check that HEAD commit exists in remote tracking branch
  - else push to remote
- check that HEAD commit exists in (upstream?configured?) repo's configured branch (how determine correct commit if it was merged/squashed?)
  - else prompt user to create PR

#### Publishing the release
- $publish_tag=$next_tag if $publish_commit doesn't have a SEMVER tag
  - else reuse existing tag (prompt user to overwrite release?somehow check if release is identical?)
- check out $publish_commit into $temp_dir
- tag with $publish_tag if necessary
- generate changelog from previous release; contains:
  - incremental commit log (with links to commits)
  - list of changed files and # lines +/- (with links to per-file diffs)
    - ^ broken out by asset, with "common" changes (shared across all assets) listed first
- build release assets using appropriate --config= and --output_base=
- commit & push docs to configured docs branch
- create release notes as "docs links" + changelog
- publish the release
  - if release fails because it already exists & points to different commit, then suggest actions to user


## Rules
#### `github_release`
Required attrs:
- `repository` (ie `<organization>/<repository_name>`)
- `version` (format: `[v]MAJOR.MINOR`)
- `deps` Targets of 'release_{tests,asset,docs}' rules
Optional attrs:
- `branch` (default master)
- `default_flags` List of default flags (eg --prerelease,--draft,etc)
- `docs` List of files to include as docs
- `docs_branch` (default docs) Any provided docs will be added to the HEAD of this branch
- `github_domain` (default github.com)

#### `release_tests`
Attrs:
- `bazel_flags`
- `tests` list of test patterns to run
- `tags` maybe find tests dynamically based on specified tags(/-negation)?

#### `release_assets`
Attrs:
- `bazel_flags`
- `srcs`
