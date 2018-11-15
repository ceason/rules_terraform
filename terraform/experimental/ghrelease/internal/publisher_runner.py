from __future__ import print_function

import argparse
import json
from collections import namedtuple

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


def main(args):
    """
    """
    # create temp dir (with {docs,artifacts} subdirs)

    accumulate_docs()

    run_test_suites()

    tag = get_next_version()
    build_artifacts()
    # check & report on both:
    # - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
    # - local branch is current with authoritative repo+branch, ie we don't
    #   need to rebase of fetchmerge (?how to ask git about this)


    if args.publish:
        pass


if __name__ == '__main__':
    main(parser.parse_args())
