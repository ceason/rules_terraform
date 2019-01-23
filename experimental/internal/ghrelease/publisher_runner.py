from __future__ import print_function

import argparse
import atexit
import json
import logging
import os
import shutil
import subprocess
import tempfile
from collections import namedtuple
from os import path

import sys

from lib import BazelFlagsEnvVar, GhHelper, SubprocessHelper, AssetPublisher


def str2bool(v):
  if v.lower() in ('yes', 'true', 't', 'y', '1'):
    return True
  elif v.lower() in ('no', 'false', 'f', 'n', '0'):
    return False
  raise argparse.ArgumentTypeError('Boolean value expected.')


def jsonfile_flag(pathstr):
  json2namedtuple = lambda d: namedtuple('X', d.keys())(*d.values())
  return json.load(open(pathstr, "r"), object_hook=json2namedtuple)


parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description="Runs pre-flight checks before publishing a new GitHub Release.")

parser.add_argument(
    '--config', type=jsonfile_flag, action='store', required=True,
    help=argparse.SUPPRESS)

parser.add_argument(
    '--draft', type=str2bool, nargs='?', const=True, default=False,
    help="")

parser.add_argument(
    '--prerelease', default=None,
    type=lambda v: str(v) if v != "" else None,
    help="An optional prerelease identifier (eg. alpha,beta,rc,pre) or empty "
         "string to indicate this is not a prerelease.")

parser.add_argument(
    '--publish', dest='publish', action='store_true',
    default=False,
    help="Publish this release to GitHub after running pre-flight checks.")

_bazel = SubprocessHelper('bazel', cwd=os.environ['BUILD_WORKSPACE_DIRECTORY'])


def run_test_suites(test_configs):
  # TODO(ceason): run_test_suites() should return a list of all source+build
  #  files relevant to the executed tests
  srcs = set()
  for t in test_configs:
    descriptor, script = tempfile.mkstemp()
    atexit.register(os.remove, script)
    print("Running test suite %s" % t.label)
    _bazel(['run', '--script_path', script, t.label])
    os.close(descriptor)
    rc = subprocess.call([script])
    if rc != 0:
      exit(rc)
  return srcs


def build_assets(asset_configs, assets_dir, tag, publish):
  # TODO(ceason): build_assets() should return two lists of files (source,build)
  #  relevant to the built assets
  srcs = set()
  build_srcs = set()

  copy_assets_args = [assets_dir]
  if publish:
    copy_assets_args.append("--publish")

  for a in asset_configs:
    descriptor, copy_assets_script = tempfile.mkstemp()
    atexit.register(os.remove, copy_assets_script)

    new_env = {k: v for k, v in os.environ.items()}
    new_env.update(a.env)
    new_env[BazelFlagsEnvVar] = json.dumps(a.bazel_flags)
    args = ["run"]
    args += a.bazel_flags
    args += ["--script_path", copy_assets_script]
    args += [a.label]
    print("Building assets %s" % a.label, end=" ...")
    _bazel(args, env=new_env)
    print("OK")
    os.close(descriptor)
    rc = subprocess.call([copy_assets_script] + copy_assets_args, env=new_env)
    if rc != 0:
      exit(rc)
  return srcs, build_srcs


def main(args):
  """
  """
  if args.draft and args.config.asset_upload_prefix:
    raise ValueError("Can't publish as draft (--draft=true) when "
                     "asset_upload_prefix is specified.")

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
      raise ValueError("docs file already exists: '%s'" % path.basename(f))
    shutil.copyfile(f, tgt_path)

  # run tests
  test_srcs = run_test_suites(args.config.test_configs)

  # git-related preflight checks
  git = GhHelper(workspace_dir, args.config.branch, args.config.docs_branch,
                 version_major=args.config.version.major,
                 version_minor=args.config.version.minor,
                 hub_binary=args.config.hub)
  git.check_local_tracks_authoritative_branch(args.publish)

  # build the assets
  tag = git.get_next_semver(args.prerelease)
  asset_srcs, build_srcs = build_assets(args.config.asset_configs, assets_dir,
                                        tag, args.publish)
  git.check_srcs_match_head(asset_srcs | test_srcs | build_srcs, args.publish)

  asset_publisher = AssetPublisher(args.config.asset_upload_prefix,
                                   git.gh_organization, git.gh_repository, tag)

  # publish assets & tag as a new GH release
  if args.publish:
    print("Publishing release to %s" % git._repo_url, file=sys.stderr)
    git.check_head_exists_in_remote()
    docs_urls = git.publish_docs(docs_dir)  # ie push them to docs_branch
    asset_urls = asset_publisher.publish_assets(assets_dir)
    release_notes = git.generate_releasenotes(docs_urls, asset_urls, asset_srcs)
    git.publish_release(assets_dir, release_notes, tag, args.draft)
  else:
    print("Finished running preflight checks. Run with '--publish' flag "
          "to publish this as a release.", file=sys.stderr)


if __name__ == '__main__':
  logging.basicConfig(stream=sys.stderr, level=logging.INFO)
  try:
    main(parser.parse_args())
    exit(0)
  except ValueError as e:
    logging.fatal(e.message)
  exit(1)
