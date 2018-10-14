from __future__ import print_function

import argparse
import os
import subprocess

import yaml

parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(dest="command")

k8s_parser = subparsers.add_parser(
    'write-k8s',
    help="Splits k8s objects into individual files, writing them to the current directory")
k8s_parser.add_argument(
    '--resolver', action='store',
    help='Executable which prints a yaml stream of k8s objects to stdout.')

tf_parser = subparsers.add_parser(
    'write-tf',
    help="Generates 'kubectl_generic_object' terraform for the provided k8s manifests.")
tf_parser.add_argument(
    '--file', action='append',
    help='File containing one or more k8s objects.')
tf_parser.add_argument(
    '--output', action='store',
    help='Output file name.')


class KubectlGenericObject:
    """
    Encapsulates logic for determining filename for a k8s
    object & referencing that file from a terraform resource.
    """

    def __init__(self, obj):
        self._obj = obj
        self.filename = "{name}-{kind}.yaml".format(
            name=self._obj['metadata']['name'],
            kind=self._obj['kind'].lower(),
        )

    def terraform_resource(self):
        # type: () -> str
        return """resource kubectl_generic_object %s_%s {
    yaml = "${file("${path.module}/%s")}"
}
""" % (
            self._obj['metadata']['name'].lower(),
            self._obj['kind'].lower(),
            self.filename)

    def content(self):
        # type: () -> str
        # strip namespace from all provided objects
        self._obj['metadata'].pop('namespace', None)
        return yaml.dump(self._obj, default_flow_style=False)

    def __lt__(self, other):
        return self.filename < other.filename


def write_tf(args):
    k8s_objects = []
    for path in args.file:
        with open(path, 'r') as f:
            for obj in yaml.load_all(f.read()):
                k8s_objects.append(KubectlGenericObject(obj))
    # create terraform resources for all of the objects
    tf = "\n".join([o.terraform_resource() for o in sorted(k8s_objects)])
    with open(args.output, "w") as f:
        f.write(tf)


def write_k8s(args):
    resolver = args.resolver.replace('${RUNFILES}', os.environ['RUNFILES'])
    try:
        stdout = subprocess.check_output([resolver])
    except subprocess.CalledProcessError as e:
        exit(e.returncode)

    for item in yaml.load_all(stdout):
        obj = KubectlGenericObject(item)
        with open(obj.filename, "w") as f:
            f.write(obj.content())


def main():
    args = parser.parse_args()
    if args.command == "write-tf":
        write_tf(args)
    elif args.command == "write-k8s":
        write_k8s(args)
    else:
        raise ValueError("Invalid command")


if __name__ == '__main__':
    main()
