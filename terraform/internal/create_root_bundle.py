from __future__ import print_function

import argparse
import tarfile
from os.path import realpath

import sys

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Description')

parser.add_argument(
    '--input_tar', action='append', default=[],
    help="Bundle of files to add to module")
parser.add_argument(
    '--input_file', action='append', default=[], nargs=2, metavar=('tgt_path', 'input_file'),
    help="Bundle of files to add to module")

parser.add_argument(
    '--output', action='store', required=True,
    help="Location of output archive")


def main(args):
    output = tarfile.open(args.output, "w:gz")

    # TODO: make sure we can't overwrite existing files

    # iterate files & add them
    for arcname, f in args.input_file:
        output.add(realpath(f), arcname=arcname)

    # iterate tars, iterate files & add them
    for t in args.input_tar:
        with tarfile.open(t, "r") as tar:
            for tarinfo in tar.getmembers():
                f = tar.extractfile(tarinfo)
                output.addfile(tarinfo, f)

    output.close()


if __name__ == '__main__':
    try:
        main(parser.parse_args())
    except ValueError as e:
        print(e, file=sys.stderr)
        exit(1)
