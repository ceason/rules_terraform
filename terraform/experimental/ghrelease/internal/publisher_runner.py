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

from lib import BazelFlagsEnvVar, GhHelper


def str2bool(v):
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')


parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description="Runs pre-flight checks before publishing a new GitHub Release.")

parser.add_argument(
    '--config', action='store', required=True,
    type=lambda pathstr: json.load(open(pathstr, "r"), object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help=argparse.SUPPRESS)

parser.add_argument(
    '--draft', type=str2bool, nargs='?', const=True, default=False,
    help="")

parser.add_argument(
    '--prerelease', type=str2bool, nargs='?', const=True, default=False,
    help="")

parser.add_argument(
    '--prerelease_identifier', action='store', default="pre",
    help="Eg. alpha,beta,rc,pre")

parser.add_argument(
    '--publish', dest='publish', action='store_true',
    default=False,
    help="Publish this release to GitHub after running pre-flight checks.")


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
    git = GhHelper(workspace_dir, args.config.branch, args.config.docs_branch,
                   version_major=args.config.version.major,
                   version_minor=args.config.version.minor,
                   hub_binary=args.config.hub)
    tag = git.get_next_semver(args.prerelease_identifier if args.prerelease else None)
    asset_srcs, build_srcs = build_assets(workspace_dir, args.config.asset_configs, assets_dir, tag, args.publish)

    # git-related preflight checks
    git.check_srcs_match_head(asset_srcs + test_srcs + build_srcs)
    git.check_local_tracks_authoritative_branch(args.publish)

    # publish assets & tag as a new GH release
    if args.publish:
        git.check_head_exists_in_remote()
        docs_links = git.publish_docs(docs_dir)  # ie push them to docs_branch
        release_notes = git.generate_changelog(docs_links, asset_srcs)
        git.publish_release(assets_dir, release_notes, tag, args.draft)


if __name__ == '__main__':
    main(parser.parse_args())
