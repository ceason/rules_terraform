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
    '--input', action='append', required=True,
    help='The template files to resolve.')

parser.add_argument(
    '--output', action='store', required=True,
    help='Output file.')

parser.add_argument(
    '--output_delimiter', action='store', default="",
    help='Output delimiter.')


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
                raise Exception("Label '%s' already exists in embeds" % label)
            embeds[label] = replacement
    for image in args.container_push:
        with open(image.digest_file, "r") as f:
            digest = f.read()
        replacement = "{registry}/{repository}@{digest}".format(
            registry=image.registry.format(**format_args),
            repository=image.repository.format(**format_args),
            digest=digest,
        )
        for label in image.valid_labels:
            if label in embeds:
                raise Exception("Label '%s' already exists in embeds" % label)
            embeds[label] = replacement
    unseen_replacements = set(embeds.values())

    # make sure..
    # - all references have exactly one embeddable
    # - all embeddables have at least one reference
    with open(args.output, "w") as output:
        for idx, input_file in enumerate(args.input):
            with open(input_file, "r") as f:
                parts = EmbeddedLabelRgx.split(f.read())
            output_content = io.BytesIO()
            is_label = False
            for s in parts:
                if is_label:
                    is_label = False
                    if s != "":
                        label = s.strip()
                        replacement = embeds.get(label)
                        if not replacement:
                            raise ValueError("No matching label found for '%s'. "
                                             "Are you sure it's listed as a dependency?" % label)
                        unseen_replacements.discard(replacement)
                        output_content.write(replacement)
                else:
                    is_label = True
                    output_content.write(s)
            if idx > 0 and args.output_delimiter:
                output.write(args.output_delimiter)
            output.write(output_content.getvalue())
    if unseen_replacements:
        raise ValueError(
            "Unreferenced dependencies. Either reference them in the template, "
            "or don't list them as dependencies. (%s)" % unseen_replacements)


def main():
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    args = parser.parse_args()
    embed(args)


if __name__ == '__main__':
    try:
        main()
    except ValueError as e:
        print(e, file=sys.stderr)
        exit(1)
