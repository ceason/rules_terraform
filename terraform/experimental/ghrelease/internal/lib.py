import os
import subprocess
from os import path

# Use this env var to determine if this script was invoked w/ the appropriate bazel flags
import semver

BazelFlagsEnvVar = "RULES_TERRAFORM_GHRELEASE_BAZEL_FLAGS"


def next_semver(major, minor, prerelease=None, versions=None):
    # type: (int, int, str, list) -> str

    semvers = [semver.parse(v[1:] if v.startswith("v") else v) for v in versions or []]
    parts = {
        "major": major,
        "minor": minor,
        "prerelease": prerelease,
    }
    if not semvers:
        parts["patch"] = 0
        parts["prerelease_patch"] = 0
    else:
        raise Exception("Unimplemented")

    if prerelease:
        return "v{major}.{minor}.{patch}-{prerelease}.{prerelease_patch}".format(**parts)
    else:
        return "v{major}.{minor}.{patch}".format(**parts)


class GhHelper:
    def __init__(self, repo_dir, branch, docs_branch, version_major, version_minor, hub_binary="hub"):
        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._hub = hub_binary
        self._version_major = version_major
        self._version_minor = version_minor

    def get_next_semver(self, prerelease):
        print("get_next_semver() unimplemented")

        x = "asdf"

        return "v0.3.0-pre.0"

    def check_srcs_match_head(self, srcs):
        """
        check & report on: (aka "local" git checks, bc we resolve locally)
        - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
        :param srcs:
        :return:
        """
        print("check_srcs_match_head() unimplemented")

    def check_up_to_date_with_authoritative_branch(self):
        """
        - local branch is current with authoritative remote+branch, ie we don't
          need to rebase or fetchmerge (?how to ask git about this)
        :return:
        """
        print("check_up_to_date_with_authoritative_branch() unimplemented")

    def check_local_tracks_authoritative_branch(self, publish):
        """
        remote tracking branch is the authoritative remote+branch (warning or err depends if we're publishing)
        :param publish:
        :return:
        """
        print("check_local_tracks_authoritative_branch() unimplemented")

    def check_head_exists_in_remote(self):
        """
        check HEAD commit exists in remote tracking branch
        - else push to remote
        :return:
        """
        print("check_head_exists_in_remote() unimplemented")
        rc = subprocess.call(["git", "push"], cwd=self._repo_dir)
        if rc != 0:
            exit(rc)

    def publish_docs(self, docs_dir):
        print("publish_docs() unimplemented")
        return []

    def generate_changelog(self, docs_links, asset_srcs):
        print("generate_changelog() unimplemented")
        return ""

    def publish_release(self, assets_dir, release_notes, tag, draft):
        hub_args = ["hub", "release", "create"]
        if draft:
            hub_args += ["--draft"]
        if "-" in tag:
            hub_args += ["--prerelease"]
        for root, dirs, files in os.walk(assets_dir):
            for f in files:
                hub_args += ["--attach=%s" % path.join(root, f)]
        hub_args += [tag]

        commit = subprocess.check_output(["git", "rev-parse", "--verify", "HEAD"], cwd=self._repo_dir)
        hub_args += ["--commitish=%s" % commit.strip()]
        hub_args += ["--message=%s\n\n%s" % (tag, release_notes)]

        rc = subprocess.call(hub_args, cwd=self._repo_dir)
        if rc != 0:
            exit(rc)
