import argparse
import json
from collections import namedtuple

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Description')

parser.add_argument(
    '--input', action='append', default=[], required=True,
    help="Source terraform files to add to output bundle. Must have unique basenames.")

parser.add_argument(
    '--modulepath', action='store', required=True,
    help="This module's path within the modules directory.")

parser.add_argument(
    '--root_resolved_output', action='store', required=True,
    help="Bundle of terraform files with module references resolved as if this were the root module.")

parser.add_argument(
    '--module_resolved_output', action='store', required=True,
    help="Bundle of terraform files with module references resolved as if this were in the modules path.")

parser.add_argument(
    '--embedded_module', action='append', default=[],
    type=lambda json_str: json.loads(json_str, object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help='JSON spec of embedded module references.')

def main(args):
    #
    raise Exception("Unimplemented")


if __name__ == '__main__':
    main(parser.parse_args())
