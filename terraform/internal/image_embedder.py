from __future__ import print_function

import argparse
import io
import json
import logging
import os
from collections import namedtuple

import httplib2
import sys
import yaml
from containerregistry.client import docker_creds_ as docker_creds
from containerregistry.client import docker_name_ as docker_name
from containerregistry.client.v2_2 import docker_image_ as v2_2_image
from containerregistry.client.v2_2 import docker_session_ as v2_2_session
from containerregistry.tools import patched_ as patched
from containerregistry.transport import transport_pool_ as transport_pool

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Embed & publish container images')

parser.add_argument(
    '--image_spec', action='append', default=[],
    type=lambda json_str: json.loads(json_str, object_hook=lambda d: namedtuple('X', d.keys())(*d.values())),
    help='JSON image spec')

subparsers = parser.add_subparsers(dest="command")

publish_parser = subparsers.add_parser(
    'publish',
    help="Publish referenced images")

embed_parser = subparsers.add_parser(
    'embed',
    help="Embed image digests into provided templates")

embed_parser.add_argument(
    '--template', action='append',
    help='The template file to resolve.')

embed_parser.add_argument(
    '--output_format', action='store', default="json",
    choices=["yaml", "json", "yml"],
    help='Output format. One of yaml,json')

embed_parser.add_argument(
    '--output_file', action='store', required=True,
    help='Output file.')

_THREADS = 32


def _resolve_path(path_str):
    if path_str and path_str.find("${RUNFILES}") != -1:
        return path_str.replace("${RUNFILES}", os.environ["RUNFILES"])
    else:
        return path_str


class ImageSpec:

    def __init__(self, spec):
        self.spec = spec
        image_chroot = ""
        if hasattr(spec, "image_chroot"):
            image_chroot = spec.image_chroot + "/"
        if hasattr(spec, "image_chroot_file"):
            with open(_resolve_path(spec.image_chroot_file), "r") as f:
                image_chroot = f.read() + "/"
        self._name_to_publish = docker_name.Tag(image_chroot + spec.name, strict=False)
        # resolve filepaths
        digests = map(_resolve_path, spec.digests)
        layers = map(_resolve_path, spec.layers)
        if len(digests) != len(layers):
            raise Exception(spec.name + ": digests & layers must have matching lengths.")
        self._layers = zip(digests, layers)
        self._tarball = _resolve_path(spec.tarball)

        if spec.config:
            with open(_resolve_path(spec.config), 'r') as reader:
                config = reader.read()
        elif self._tarball:
            with v2_2_image.FromTarball(self._tarball) as base:
                config = base.config_file()
        else:
            raise Exception(spec.name + ': Either "config" or "tarball" must be specified.')
        self._config = config

    def publish(self, transport, threads=_THREADS):
        creds = docker_creds.DefaultKeychain.Resolve(self._name_to_publish)
        with v2_2_session.Push(self._name_to_publish, creds, transport, threads=_THREADS) as session:
            with v2_2_image.FromDisk(self._config, self._layers, legacy_base=self._tarball) as image:
                # todo: output more friendly error message when this raises an exception
                session.upload(image)

    def name_to_embed(self):
        with v2_2_image.FromDisk(self._config, self._layers, legacy_base=self._tarball) as image:
            return '{repository}@{digest}'.format(
                repository=self._name_to_publish.as_repository(),
                digest=image.digest())


def embed(args):
    """

    :param args:
    :return:
    """
    outputs = []
    # calculate image digests; make dict of 'name' to 'digest' (ie 'search_text' to 'replacement')
    embedded_image_digests = {}
    for spec in args.image_spec:
        image = ImageSpec(spec)
        embedded_image_digests[image.spec.name] = image.name_to_embed()
    unseen_strings = set(embedded_image_digests.keys())

    # - load all of the inputs
    # - walk all leaf nodes
    #   - if leaf node in 'embedded_images', then replace w/ digest
    def walk_dict(d):
        return {
            walk(key): walk(d[key])
            for key in d
        }

    def walk_list(l):
        return [walk(e) for e in l]

    def walk_string(s):
        if s in embedded_image_digests:
            unseen_strings.discard(s)
            return embedded_image_digests[s]
        else:
            return s

    def walk(o):
        if isinstance(o, dict):
            return walk_dict(o)
        if isinstance(o, list):
            return walk_list(o)
        if isinstance(o, str):
            return walk_string(o)
        return o

    for path in args.template:
        with open(path, 'r') as f:
            input_str = f.read()
        if path.endswith(".json"):
            input_str = json.dumps(json.loads(input_str))
        outputs.extend(map(walk, yaml.load_all(input_str)))

    if len(outputs) == 0:
        logging.fatal("Nothing to resolve (Are you sure the input has valid json/yaml objects?)")
        sys.exit(1)

    if len(unseen_strings) > 0:
        msg = 'The following image references were not found:\n    '
        msg = msg + "\n    ".join(unseen_strings)
        logging.fatal(msg)
        sys.exit(1)

    output_content = io.BytesIO()
    if args.output_format == "json":
        # pretty-print if there's only one json object
        if len(outputs) == 1:
            json.dump(outputs[0], output_content, indent=2)
        else:
            for o in outputs:
                json.dump(o, output_content)
    elif args.output_format in ["yaml", "yml"]:
        yaml.dump_all(outputs, output_content, default_flow_style=False)
    else:
        raise ValueError("Unknown output format %s" % args.output_format)
    with open(args.output_file, "w") as f:
        f.write(output_content.getvalue())
        output_content.close()


def publish(args):
    """

    :param args:
    :return:
    """
    transport = transport_pool.Http(httplib2.Http, size=_THREADS)
    for spec in args.image_spec:
        image = ImageSpec(spec)
        image.publish(transport)


def main():
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    args = parser.parse_args()

    if args.command == "embed":
        embed(args)
    elif args.command == "publish":
        publish(args)
    else:
        raise Exception("Unknown command '%s'" % args.command)


if __name__ == '__main__':
    with patched.Httplib2():
        main()
