from __future__ import print_function

import argparse

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Compute URL for a content addressable file')

parser.add_argument(
    '--url_prefix', action='store', required=True,
    help='Prefix of url')

parser.add_argument(
    '--digest', action='store', required=True,
    help='File containing digest.')

parser.add_argument(
    '--file_basename', action='store', required=True,
    help='Name of file.')

parser.add_argument(
    '--output', action='store', required=True,
    help='Output file.')

parser.add_argument(
    '--stamp_info_file', action='append', default=[],
    help='File from which to read stamp replacements')

if __name__ == '__main__':
    args = parser.parse_args()
    # build dict of substitutions if there are any
    format_args = {}
    for infofile in args.stamp_info_file:
        with open(infofile) as info:
            for line in info:
                line = line.strip('\n')
                key, value = line.split(' ', 1)
                if key in format_args:
                    print(('WARNING: Duplicate value for key "%s": '
                           'using "%s"' % (key, value)))
                format_args[key] = value
    with open(args.digest, "r") as f:
        digest = f.read().lower()
    url = "{prefix}{xx}/{digest}/{basename}".format(
        prefix=args.url_prefix.format(**format_args),
        xx=digest[:2],
        digest=digest,
        basename=args.file_basename
    )
    with open(args.output, "w") as out:
        out.write(url)
