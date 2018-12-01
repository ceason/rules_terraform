from __future__ import print_function

import argparse
import io
import json
import logging
import re
from collections import namedtuple

import sys

EmbeddedLabelRgx = re.compile("\{\{[ ]*embedded_reference[ ]*(.*?)\}\}")

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Embed & publish container images')

parser.add_argument(
    '--container_push', action='append', default=[],
    type=lambda json_str: json.loads(json_str, object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help='JSON image spec')

parser.add_argument(
    '--content_addressable_file', action='append', default=[],
    type=lambda json_str: json.loads(json_str, object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help='JSON content addressable file spec')

parser.add_argument(
    '--stamp_info_file', action='append', default=[],
    help='File from which to read stamp replacements')

parser.add_argument(
    '--template', action='store', required=True,
    help='The template file to resolve.')

parser.add_argument(
    '--output', action='store', required=True,
    help='Output file.')


def embed(args):
    """

    :param args:
    :return:
    """

    # print(args)
    # exit(1)

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
    # collect all embeddables
    # label => replacement str
    embeds = {}
    for cas_file in args.content_addressable_file:
        with open(cas_file.url_file, "r") as f:
            replacement = f.read()
        for label in cas_file.valid_labels:
            if label in embeds:
                raise Exception("Label '%s' already exists in embeds")
            embeds[label] = replacement
    for image in args.image_spec:
        with open(image.digest_file, "r") as f:
            digest = f.read()
        replacement = "{registry}/{repository}@{digest}".format(
            registry=image.registry.format(**format_args),
            repository=image.repository.format(**format_args),
            digest=digest,
        )
        for label in image.valid_labels:
            if label in embeds:
                raise Exception("Label '%s' already exists in embeds")
            embeds[label] = replacement

    # make sure..
    # - all references have exactly one embeddable
    # - all embeddables have at least one reference

    with open(args.template, "r") as f:
        parts = EmbeddedLabelRgx.split(f.read())
    if len(parts) < 2:
        raise ValueError("Could not find any embedded references within the template file.")
    output_content = io.BytesIO()
    is_label = True
    for s in parts:
        if is_label:
            is_label = False
            if s != "":
                replacement = embeds.get(s.strip())
                if not replacement:
                    raise ValueError("No matching label found for '%s' referenced in template file. "
                                     "Are you sure it's listed in deps?")
                output_content.write(replacement)
        else:
            is_label = True
            output_content.write(s)
    with open(args.output_file, "w") as f:
        f.write(output_content.getvalue())


def main():
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    args = parser.parse_args()
    embed(args)


if __name__ == '__main__':
    main()
