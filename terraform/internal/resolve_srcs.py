import argparse

parser = argparse.ArgumentParser(
    fromfile_prefix_chars='@',
    description='Description')


def main(args):
    raise Exception("Unimplemented")


if __name__ == '__main__':
    main(parser.parse_args())
