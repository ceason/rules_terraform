import argparse
import collections
import os
import tarfile

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Bundle terraform files into an archive')

parser.add_argument(
    '--file', action='append', metavar=('tgt_path', 'src'), nargs=2, default=[],
    help="'src' file will be added to 'tgt_path'")

parser.add_argument(
    '--embed', action='append', metavar=('embed_path', 'src_tar'), nargs=2, default=[],
    help="'src' archive will be embedded in 'embed_path'. If 'embed_path=.' then archive content will be merged into "
         "the output root")

parser.add_argument(
    '--output', action='store', required=True,
    help="Output path of bundled archive")

BundleItem = collections.namedtuple('BundleItem', 'tarinfo file')


class Bundle:

    def __init__(self, output):
        # map of paths to BundleItems
        self._file_map = {}
        self._output = tarfile.open(output, "w")

    def add(self, src, arcname):
        f = open(os.path.realpath(src), 'r')
        tarinfo = self._output.gettarinfo(arcname=arcname, fileobj=f)
        if self._file_map.has_key(tarinfo.name):
            raise ValueError("File '%s' is already in archive" % tarinfo.name)
        tarinfo.mtime = 0  # zero out modification time
        self._file_map[tarinfo.name] = BundleItem(tarinfo, f)

    def embed(self, archive, embed_path):
        tar = tarfile.open(archive)
        for tarinfo in tar.getmembers():
            f = tar.extractfile(tarinfo)
            if embed_path != ".":
                tarinfo.name = embed_path + "/" + tarinfo.name
            if self._file_map.has_key(tarinfo.name):
                raise ValueError("File '%s' is already in archive" % tarinfo.name)
            self._file_map[tarinfo.name] = BundleItem(tarinfo, f)

    def finish(self):
        for path in sorted(self._file_map.keys()):
            tarinfo, f = self._file_map[path]
            self._output.addfile(tarinfo, fileobj=f)


def main(args):
    """

    :return:
    """

    # output = tarfile.open(args.output, "w")
    bundle = Bundle(args.output)

    # add each args.file
    for tgt_path, src in args.file:
        bundle.add(src, tgt_path)
    # embed each args.embed
    for embed_path, src_tar in args.embed:
        bundle.embed(src_tar, embed_path)

    bundle.finish()

if __name__ == '__main__':
    main(parser.parse_args())
