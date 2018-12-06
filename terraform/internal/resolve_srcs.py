from __future__ import print_function

import argparse
import io
import json
import re
import tarfile
from StringIO import StringIO
from collections import namedtuple
from os.path import basename

import sys

ModuleSourceRgx = re.compile('(\s*["]?source["]?\s*=\s*)"([@/:].*?)"')

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
    # ModuleSourceReplacement = namedtuple('X', 'module root')
    #
    # collect all embeddables
    # label => replacement str
    embeds = {}
    modules = {}

    for m in args.embedded_module:
        if m.modulepath in modules:
            if m.label == modules[m.modulepath]:
                continue
            else:
                raise ValueError("Multiple modules can't have the same modulepath (modulepath=%s, modules=[%s,%s])" % (
                    m.modulepath, m.label, modules[m.modulepath]
                ))
        modules[m.modulepath] = m.label
        for label in m.valid_labels:
            if label in embeds:
                raise Exception("Label '%s' already exists in embeds" % label)
            embeds[label] = m.modulepath
    unseen_replacements = set(embeds.values())

    # iterate over input files & write to output
    root_resolved_output = tarfile.open(args.root_resolved_output, "w")
    module_resolved_output = tarfile.open(args.module_resolved_output, "w")

    seen_srcs = set()

    # make sure..
    # - all references have exactly one embeddable
    # - all embeddables have at least one reference
    for fpath in sorted(set(args.input)):
        file_basename = basename(fpath)
        if file_basename in seen_srcs:
            raise ValueError("Duplicate file %s. Files must have unique basenames." % file_basename)
        seen_srcs.add(file_basename)
        root_output = io.BytesIO()
        module_output = io.BytesIO()
        with open(fpath, 'r') as f:
            parts = ModuleSourceRgx.split(f.read())
        # non-matched content is always returned first
        content = parts.pop(0)
        root_output.write(content)
        module_output.write(content)
        # iterate over each piece of content & associated capture group
        num_capture_groups = 2
        for prefix, label, suffix in [parts[i:i + num_capture_groups + 1]
                                      for i in range(0, len(parts), num_capture_groups + 1)]:
            root_output.write(prefix)
            module_output.write(prefix)
            modulepath = embeds.get(label)
            if not modulepath:
                raise ValueError("No matching label found for '%s'. "
                                 "Are you sure it's listed as a dependency?" % label)
            unseen_replacements.discard(modulepath)
            # TODO: make this work when modulepath has multiple path components (eg "path/to/my/module")
            module_replacement = str('"../%s"' % modulepath)
            root_replacement = str('"./modules/%s"' % modulepath)

            root_output.write(root_replacement)
            root_output.write(suffix)

            module_output.write(module_replacement)
            module_output.write(suffix)

        root_filename = file_basename
        module_filename = file_basename

        root_output_value = root_output.getvalue()
        root_tarinfo = tarfile.TarInfo(root_filename)
        root_tarinfo.size = len(root_output_value)
        root_resolved_output.addfile(root_tarinfo, StringIO(root_output_value))

        module_output_value = module_output.getvalue()
        module_tarinfo = tarfile.TarInfo(module_filename)
        module_tarinfo.size = len(module_output_value)
        module_resolved_output.addfile(module_tarinfo, StringIO(module_output_value))

    if unseen_replacements:
        raise ValueError(
            "Unreferenced dependencies. Either reference them in the template, "
            "or don't list them as dependencies. (%s)" % ", ".join([
                modules[modulepath]
                for modulepath in sorted(list(unseen_replacements))
            ]))
    module_resolved_output.close()
    root_resolved_output.close()


if __name__ == '__main__':
    try:
        main(parser.parse_args())
    except ValueError as e:
        print(e, file=sys.stderr)
        exit(1)
