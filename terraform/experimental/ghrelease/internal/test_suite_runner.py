from __future__ import print_function

import argparse
import json
import os
import subprocess

parser = argparse.ArgumentParser(
    description="")

parser.add_argument(
    '--config', action='store', required=True,
    type=lambda path: json.load(open(path, "r")),
    help=argparse.SUPPRESS)


def main(args):
    """
    """
    tests = args.config['tests']
    bazel_flags = args.config['bazel_flags']
    env = args.config['env']

    if len(tests) == 0:
        raise ValueError("Config does not contain any tests")
    args = ["bazel", "test"]
    args.extend(bazel_flags)
    args.append("--")
    args.extend(tests)
    workspace_dir = os.environ['BUILD_WORKSPACE_DIRECTORY']
    environment = {k: v for k, v in os.environ.items()}
    environment.update(env)
    rc = subprocess.call(args, cwd=workspace_dir, env=environment)
    if rc == 4:
        # return code 4 means no tests found, so it's "successful"
        exit(0)
    else:
        exit(rc)


if __name__ == '__main__':
    main(parser.parse_args())
