from __future__ import print_function

import argparse
import os
import shutil
import subprocess
import tarfile

import errno
import sys

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Render a Terraform workspace & outputs location of wrapper binary to stdout')

parser.add_argument(
    '--tfroot_archive', action='store', required=True,
    help='Target directory for the output. This will be used as the terraform root.')

parser.add_argument(
    '--plugin_file', action='append', metavar=('tgt_path', 'src'), nargs=2, default=[],
    help="'src' file will be copied to 'tgt_path', relative to 'plugin_dir'")

parser.add_argument(
    '--prerender_hook', action='append', default=[],
    help="Binaries to run prior to rendering the workspace")

parser.add_argument(
    '--symlink_plugins', dest='symlink_plugins', action='store_true',
    default=False,
    help="Symlink plugin files into the output directory rather than copying them (note: not currently implemented)")

parser.add_argument(
    'output_dir', action='store',
    help='Target directory for the output.')

# language=bash
_LAUNCHER_TEMPLATE = """#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

: ${TMPDIR:=/tmp}
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:=$TMPDIR/rules_terraform/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

cd "$(dirname "$0")/../"
tfroot="$PWD/.terraform/tfroot"

# figure out which command we are running
if [ $# -gt 0 ]; then
  command=$1; shift
else
  command="-help"
fi

case "$command" in
# these commands don't take 'tfroot' as an arg
workspace|import|output|taint|untaint|state|debug|-help|version)
  exec terraform "$command" "$@"
  ;;
*) # all other commands take tfroot as an arg
  exec terraform "$command" "$@" "$tfroot"
  ;;
esac
"""


def put_file(output_path, src=None, content=None, overwrite=False):
    """

    :param overwrite:
    :param output_path:
    :param src: Source file, will be copied to output_path (mutually exclusive with 'content')
    :param content: File content which will be written to output_path (mutually exclusive with 'src')
    :return:
    """
    if src and content:
        raise ValueError("Only one of 'src' or 'content' may be specified.")
    if not (src or content):
        raise ValueError("Must specify 'src' or 'content'.")
    # make sure file doesn't already exist
    if os.path.isfile(output_path):
        if overwrite:
            os.remove(output_path)
        else:
            raise AssertionError("Target file already exists: '%s'" % output_path)
    # create the parent dir
    try:
        os.makedirs(os.path.dirname(output_path), mode=0755)
    except OSError as e:
        # ignore if existing dir, but raise otherwise
        if e.errno != errno.EEXIST:
            raise
    # copy or put le file!
    if src:
        shutil.copyfile(src, output_path)
        shutil.copymode(src, output_path)
    else:
        with open(output_path, "w") as f:
            f.write(content)


def main(args):
    # run prerender hooks
    for hook in args.prerender_hook:
        rc = subprocess.call([hook], stdout=sys.stderr)
        if rc != 0:
            exit(rc)

    # extract tfroot
    tfroot = args.output_dir + "/.terraform/tfroot/"
    try:
        # clean up old tfroot if exists
        shutil.rmtree(tfroot)
    except OSError as e:
        # ignore "directory doesn't exist" exception
        if e.errno != errno.ENOENT:
            raise e
    try:
        # create the parent dir
        os.makedirs(os.path.dirname(tfroot), mode=0755)
    except OSError as e:
        # ignore if existing dir, but raise otherwise
        if e.errno != errno.EEXIST:
            raise e
    tfroot_archive = tarfile.open(args.tfroot_archive)
    tfroot_archive.extractall(tfroot)

    # write plugin files
    for tgt, src in args.plugin_file:
        tgt_abs = args.output_dir + "/.terraform/plugins/" + tgt
        put_file(tgt_abs, src, overwrite=True)

    # write the launcher
    launcher_file = args.output_dir + "/.terraform/terraform.sh"
    launcher = open(launcher_file, "w")
    launcher.write(_LAUNCHER_TEMPLATE)
    launcher.close()
    os.chmod(launcher_file, 0o755)
    print(launcher_file, file=sys.stdout)


if __name__ == '__main__':
    main(parser.parse_args())
