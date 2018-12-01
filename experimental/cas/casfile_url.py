from __future__ import print_function

import argparse
import hashlib
import os

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Compute URL for a content addressable file')

parser.add_argument(
    '--url_prefix', action='store', required=True,
    help='Prefix of url')

parser.add_argument(
    '--input', action='store', required=True,
    help='The file.')

parser.add_argument(
    '--output', action='store', required=True,
    help='Output file.')

if __name__ == '__main__':
    args = parser.parse_args()
    with open(args.input, "rb") as inputfile:
        sha256 = hashlib.sha256()
        while True:
            data = inputfile.read(65536)
            if not data:
                break
            sha256.update(data)
    digest = sha256.hexdigest().lower()
    url = "{prefix}/{xx}/{digest}/{basename}".format(
        prefix=args.url_prefix,
        xx=digest[:2],
        digest=digest,
        basename=os.path.basename(args.input)
    )
    with open(args.output, "w") as out:
        out.write(url)
