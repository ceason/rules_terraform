from __future__ import print_function

import argparse
import logging

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Publish file to specified URL')

parser.add_argument(
    '--url', action='store', required=True,
    help='Path to file containing URL where to upload')

parser.add_argument(
    '--file', action='store', required=True,
    help='File to upload.')

def publish_s3(file, url):
    """

    :param file:
    :param url:
    :return:
    """
    raise Exception("Unimplemented.")


def main(args):
    with open(args.url, "r") as f:
        url = f.read()
    if url.startswith("s3://"):
        publish_s3(args.file, url)
    else:
        raise ValueError("Unsupported url '%s'. Currently only support 's3://' urls.")

if __name__ == '__main__':
    try:
        main(parser.parse_args())
    except ValueError as e:
        logging.fatal(e.message)
        exit(1)


