from __future__ import print_function

import argparse
import tarfile

import yaml

try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

parser = argparse.ArgumentParser(
    description="Generates 'kubectl_generic_object' terraform for the provided k8s manifests "
                "& splits k8s yaml to individual files")

parser.add_argument(
    '--input', action='append', required=True,
    help='File containing one or more k8s objects.')
parser.add_argument(
    '--tf_filename', action='store', required=True,
    help='Filename for the generated terraform file.')
parser.add_argument(
    '--output', action='store', required=True,
    help='Output tar file name.')


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


def main():
    args = parser.parse_args()
    output = tarfile.open(args.output, "w")

    k8s_objects = []
    for path in args.input:
        with open(path, 'r') as f:
            for item in yaml.load_all(f.read()):
                obj = KubectlGenericObject(item)
                k8s_objects.append(obj)
    # sort so output is deterministic
    k8s_objects = sorted(k8s_objects)
    # create terraform resources for all of the objects
    tf = "\n".join([o.terraform_resource() for o in k8s_objects])
    tarinfo = tarfile.TarInfo(args.tf_filename)
    tarinfo.size = len(tf)
    output.addfile(tarinfo, StringIO(tf))
    # write the individual object files
    for obj in k8s_objects:
        obj_content = obj.content()
        tarinfo = tarfile.TarInfo(obj.filename)
        tarinfo.size = len(obj_content)
        output.addfile(tarinfo, StringIO(obj_content))
    output.close()


if __name__ == '__main__':
    main()
