from __future__ import print_function

import argparse
import logging
import os
try:
    from urlparse import urlparse
except ImportError:
    from urllib.parse import urlparse

import boto3
import botocore
import sys
from boto3.s3.transfer import S3Transfer

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Publish file to specified URL')

parser.add_argument(
    '--url', action='store', required=True,
    help='Path to file containing URL where to upload')

parser.add_argument(
    '--file', action='store', required=True,
    help='File to upload.')


def publish_s3(file_path, url):
    o = urlparse(url)
    bucket = o.hostname
    key = o.path.lstrip("/")
    file_path = os.path.realpath(file_path)
    file_size = os.path.getsize(file_path)

    def sizeof_fmt(num, use_kibibyte=True):
        base, suffix = [(1000., 'B'), (1024., 'iB')][use_kibibyte]
        for x in ['B'] + map(lambda x: x + suffix, list('kMGTP')):
            if -base < num < base:
                return "%3.1f%s" % (num, x)
            num /= base
        return "%3.1f%s" % (num, x)

    fmt_args = {
        "url": url,
        "size": sizeof_fmt(file_size),
    }

    s3 = boto3.client('s3')
    """ :type : pyboto3.s3 """
    try:
        existing_s3_object = s3.head_object(Bucket=bucket, Key=key)
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            existing_s3_object = None
        else:
            raise

    if existing_s3_object is not None:
        logging.info("Already exists, skipping upload of {size} file ({url})".format(**fmt_args))
        return

    with S3Transfer(s3) as transfer:
        logging.info("Uploading {size} file ({url})".format(**fmt_args))
        transfer.upload_file(file_path, bucket, key)
        logging.info("Upload completed successfully")


def main(args):
    with open(args.url, "r") as f:
        url = f.read()
    if url.startswith("s3://"):
        publish_s3(args.file, url)
    else:
        raise ValueError("Unsupported url '%s'. Currently only support 's3://' urls.")


if __name__ == '__main__':
    # publish_s3("some-test-filename", "s3://cool-nginx-test-bucket/test/asdfasdfs.key")
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    try:
        main(parser.parse_args())
    except ValueError as e:
        logging.fatal(e.message)
        exit(1)
