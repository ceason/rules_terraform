from __future__ import print_function

import argparse
import errno
import json
import os
import shutil
import subprocess
import sys
from collections import namedtuple
from os import path

from lib import BazelFlagsEnvVar

parser = argparse.ArgumentParser(
    description="Builds artifacts & outputs them to the specified directory")

parser.add_argument(
    '--config', action='store', required=True,
    type=lambda pathstr: json.load(open(pathstr, "r"), object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help=argparse.SUPPRESS)

parser.add_argument(
    '--overwrite', dest='overwrite', action='store_true',
    default=False,
    help="Overwrite existing files in output_dir")

parser.add_argument(
    '--publish', dest='publish', action='store_true',
    default=False,
    help="Publish dependant assets such as docker images whose digests may be embedded in transitive assets.")

parser.add_argument(
    'output_dir', action='store',
    help='')


def main(args):
    """
    """
    # canonicalize 'output_dir' relative to BUILD_WORKING_DIRECTORY
    output_dir = args.output_dir
    if not path.isabs(output_dir):
        output_dir = path.join(os.environ['BUILD_WORKING_DIRECTORY'], output_dir)
        output_dir = path.normpath(output_dir)
    try:
        # create the output dir
        os.makedirs(output_dir, mode=0o755)
    except OSError as e:
        # ignore if existing dir, but raise otherwise
        if e.errno != errno.EEXIST:
            raise e

    # reinvoke bazel with the correct flags if necessary
    correct_flags = json.dumps(args.config.bazel_flags)
    if correct_flags != os.getenv(BazelFlagsEnvVar):
        new_env = {k: v for k, v in os.environ.items()}
        new_env.update(args.config.env)
        new_env[BazelFlagsEnvVar] = correct_flags
        cmd = ["bazel", "run"]
        cmd.extend(args.config.bazel_flags)
        cmd.append(args.config.label)
        cmd.append("--")
        cmd.extend(sys.argv[1:])
        print("Reinvoking bazel with flags: %s" % " ".join(args.config.bazel_flags))
        os.chdir(os.environ['BUILD_WORKING_DIRECTORY'])
        os.execvpe(cmd[0], cmd, new_env)

    # invoke docker image publisher
    if args.publish:
        rc = subprocess.call([args.config.image_publisher])
        if rc != 0:
            print("Error, failed to publish images! D:")
            exit(rc)

    # copy each of the provided assets to the output dir
    for f in args.config.assets:
        tgt_path = path.join(output_dir, path.basename(f))
        if path.exists(tgt_path) and not args.overwrite:
            print("Error, file already exists in output_dir: '%s'" % path.basename(f))
            exit(1)
        src_path = path.realpath(f)
        shutil.copyfile(src_path, tgt_path)


if __name__ == '__main__':
    main(parser.parse_args())
