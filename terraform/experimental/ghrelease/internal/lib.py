from __future__ import print_function

import os
import re
import subprocess
from os import path

# Use this env var to determine if this script was invoked w/ the appropriate bazel flags
import semver
import sys
from semver import VersionInfo

BazelFlagsEnvVar = "RULES_TERRAFORM_GHRELEASE_BAZEL_FLAGS"


def next_semver(major, minor, prerelease=None, versions=None):
    # type: (int, int, str, list) -> str
    major = int(major)
    minor = int(minor)

    def stuff_we_care_about(v):
        """
        we only care about stuff that:
        - has our same major+minor version
        - is a release OR has our same prerelease token
        """
        if v.major != major:
            return False
        if v.minor != minor:
            return False
        if not prerelease:
            return True
        if v.prerelease is None:
            return True
        prefix = prerelease + "."
        if v.prerelease.startswith(prefix):
            # also needs to end in an int for us to care about it
            return bool(re.match("^\d+$", v.prerelease[len(prefix):]))
        return False

    semvers = [
        VersionInfo.parse(v[1:] if v.startswith("v") else v)
        for v in versions or []
    ]
    semvers = filter(stuff_we_care_about, semvers)
    if semvers:
        latest = sorted(semvers)[-1]
        version = str(latest)
        # do we bump patch?
        if not latest.prerelease:
            version = semver.bump_patch(version)
        # is this a final version?
        if prerelease:
            version = semver.bump_prerelease(version, prerelease)
        else:
            version = semver.finalize_version(version)
    else:
        # nothing exists on the current minor version so create a new one
        version = "%s.%s.0" % (major, minor)
        if prerelease:
            version += "-%s.1" % prerelease
    return "v" + version


class GhHelper:
    def __init__(self, repo_dir, branch, docs_branch, version_major,
                 version_minor, hub_binary="hub"):
        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._version_major = version_major
        self._version_minor = version_minor
        self._hub = path.abspath(hub_binary)

    def get_next_semver(self, prerelease):
        args = [self._hub, "release"]
        tags = subprocess.check_output(args, cwd=self._repo_dir).splitlines()
        return next_semver(self._version_major, self._version_minor,
                           prerelease, tags)

    def check_srcs_match_head(self, srcs):
        """
        check & report on: (aka "local" git checks, bc we resolve locally)
        - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
        :param srcs:
        :return:
        """
        print("check_srcs_match_head() unimplemented")

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
        try:
            print("check_head_exists_in_remote", end="...")
            sys.stdout.flush()
            sys.stderr.flush()
            subprocess.check_call(["git", "push"],
                                  cwd=self._repo_dir)
        except subprocess.CalledProcessError as e:
            exit(e.returncode)

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
        if sys.stdout.isatty():
            hub_args.append("--browse")

        rc = subprocess.call(hub_args, cwd=self._repo_dir)
        if rc != 0:
            exit(rc)
        # get the new tag (if this wasn't a draft)
        if not draft:
            subprocess.call(["git", "fetch", "--tags"], cwd=self._repo_dir)
