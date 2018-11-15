from __future__ import print_function

import argparse
import atexit
import json
import os
import shutil
import subprocess
import tempfile
from collections import namedtuple
from os import path

BazelFlagsEnvVar = "RULES_TERRAFORM_GHRELEASE_BAZEL_FLAGS"

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description="Runs pre-flight checks before publishing a new GitHub Release.")

parser.add_argument(
    '--config', action='store', required=True,
    type=lambda pathstr: json.load(open(pathstr, "r"), object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help=argparse.SUPPRESS)

parser.add_argument(
    '--draft', dest='draft', action='store_true',
    default=False,
    help="")

parser.add_argument(
    '--prerelease', dest='prerelease', action='store_true',
    default=False,
    help="")

parser.add_argument(
    '--publish', dest='publish', action='store_true',
    default=False,
    help="Publish this release to GitHub after running pre-flight checks.")


class GitHelper:
    def __init__(self, repo_dir, branch, docs_branch, hub_binary):
        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._authoritative_remote = "???"
        self._hub = hub_binary

    def get_next_semver(self, version, prerelease):
        print("get_next_semver() unimplemented")
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


def run_test_suites(workspace_dir, test_configs):
    srcs = []
    print("todo: run_test_suites() should return a list of all source+build files relevant to the executed tests")
    for t in test_configs:
        args = ["bazel", "run", t.label]
        rc = subprocess.call(args, cwd=workspace_dir)
        if rc != 0:
            exit(rc)
    return srcs


def build_assets(workspace_dir, asset_configs, assets_dir, tag, publish):
    srcs = []
    build_srcs = []
    print("todo: build_assets() should return two lists of files (source,build) relevant to the built assets")
    for a in asset_configs:
        new_env = {k: v for k, v in os.environ.items()}
        new_env.update(a.env)
        new_env[BazelFlagsEnvVar] = json.dumps(a.bazel_flags)
        args = ["bazel", "run"]
        args += a.bazel_flags
        args += [a.label, "--", assets_dir]
        if publish:
            args += ["--publish"]
        rc = subprocess.call(args, cwd=workspace_dir, env=new_env)
        if rc != 0:
            exit(rc)
    return srcs, build_srcs


def main(args):
    """
    """
    workspace_dir = os.environ['BUILD_WORKSPACE_DIRECTORY']

    # create temp dirs
    docs_dir = tempfile.mkdtemp()
    assets_dir = tempfile.mkdtemp()
    atexit.register(shutil.rmtree, docs_dir, ignore_errors=True)
    atexit.register(shutil.rmtree, assets_dir, ignore_errors=True)

    # copy docs
    for f in args.config.docs:
        tgt_path = path.join(docs_dir, path.basename(f))
        if path.exists(tgt_path):
            print("Error, docs file already exists: '%s'" % path.basename(f))
            exit(1)
        shutil.copyfile(f, tgt_path)

    # run tests
    test_srcs = run_test_suites(workspace_dir, args.config.test_configs)

    # build the assets
    git = GitHelper(workspace_dir, args.config.branch, args.config.docs_branch, args.config.hub)
    tag = git.get_next_semver(args.config.version, args.prerelease)
    asset_srcs, build_srcs = build_assets(workspace_dir, args.config.asset_configs, assets_dir, tag, args.publish)

    # git-related preflight checks
    git.check_srcs_match_head(asset_srcs + test_srcs + build_srcs)
    git.check_up_to_date_with_authoritative_branch()
    git.check_local_tracks_authoritative_branch(args.publish)

    # publish assets & tag as a new GH release
    if args.publish:
        git.check_head_exists_in_remote()
        docs_links = git.publish_docs(docs_dir)  # ie push them to docs_branch
        release_notes = git.generate_changelog(docs_links, asset_srcs)
        git.publish_release(assets_dir, release_notes, tag, args.draft)


if __name__ == '__main__':
    main(parser.parse_args())
