from __future__ import print_function

import argparse
import atexit
import json
import os
import shutil
import tempfile
from collections import namedtuple
from os import path

parser = argparse.ArgumentParser(
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
    def __init__(self, repo_dir, branch, docs_branch):
        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._authoritative_remote = "???"

    def get_next_semver(self, version, prerelease):
        pass

    def check_srcs_match_head(self, srcs):
        """
        check & report on: (aka "local" git checks, bc we resolve locally)
        - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
        :param srcs:
        :return:
        """
        pass

    def check_up_to_date_with_authoritative_branch(self):
        """
        - local branch is current with authoritative remote+branch, ie we don't
          need to rebase or fetchmerge (?how to ask git about this)
        :return:
        """
        pass

    def check_local_tracks_authoritative_branch(self, publish):
        """
        remote tracking branch is the authoritative remote+branch (warning or err depends if we're publishing)
        :param publish:
        :return:
        """
        pass

    def check_head_exists_in_remote(self):
        """
        check HEAD commit exists in remote tracking branch
        - else push to remote
        :return:
        """
        pass

    def publish_docs(self, docs_dir):
        pass

    def generate_changelog(self, docs_links, asset_srcs):
        pass

    def publish_release(self, assets_dir, release_notes, tag, draft):
        pass


def run_test_suites(workspace_dir, test_configs):
    srcs = []
    return srcs


def build_assets(workspace_dir, asset_configs, assets_dir, tag):
    srcs = []
    build_srcs = []
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
    git = GitHelper(workspace_dir, args.config.branch, args.config.docs_branch)
    tag = git.get_next_semver(args.config.version, args.prerelease)
    asset_srcs, build_srcs = build_assets(workspace_dir, args.config.asset_configs, assets_dir, tag)

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
