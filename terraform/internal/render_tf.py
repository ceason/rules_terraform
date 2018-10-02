import argparse
import os
import shutil
import subprocess

import errno
import yaml

parser = argparse.ArgumentParser(
	fromfile_prefix_chars='@',
	description='Render a Terraform workspace & associated plugins dir')

parser.add_argument(
	'--k8s_object', action='append', metavar=('output_prefix', 'resolver'), nargs=2, default=[],
	help='File that when executed, outputs a yaml stream of k8s objects')

parser.add_argument(
	'--file', action='append', metavar=('tgt_path', 'src'), nargs=2, default=[],
	help="'src' file will be copied to 'tgt_path', relative to 'output_dir'")

parser.add_argument(
	'--plugin_file', action='append', metavar=('tgt_path', 'src'), nargs=2, default=[],
	help="'src' file will be copied to 'tgt_path', relative to 'plugin_dir'")

parser.add_argument(
	'--output_dir', action='store',
	help='Target directory for the output. This will be used as the terraform root.')

parser.add_argument(
	'--plugin_dir', action='store',
	help='Location to place terraform plugin files (eg .terraform/plugins, terraform.d/plugins, etc ). If unspecified, no plugin files will be output.')

parser.add_argument(
	'--symlink_plugins', dest='symlink_plugins', action='store_true',
	default=False,
	help="Symlink plugin files into the output directory rather than copying them (note: not currently implemented)")


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
	for tgt, src in args.file:
		tgt_abs = args.output_dir + "/" + tgt
		put_file(tgt_abs, src)

	# only write plugin files if the plugin_dir was specified
	if args.plugin_dir:
		for tgt, src in args.plugin_file:
			tgt_abs = args.plugin_dir + "/" + tgt
			put_file(tgt_abs, src, overwrite=True)

	# for each k8s_object.,
	# - split resolver output to individual object files
	# - write files underneath appropriate directory
	# - accumulate resources into terraform file
	k8s_tf_files = {}
	for item in args.k8s_object:
		prefix, resolver = item
		stdout = subprocess.check_output([resolver])
		for k8s_object in yaml.load_all(stdout):
			# strip 'namespace' if it's present
			k8s_object['metadata'].pop('namespace', None)
			content = yaml.dump(k8s_object, default_flow_style=False)
			filename = "{name}-{kind}.yaml".format(
				name=k8s_object['metadata']['name'],
				kind=k8s_object['kind'].lower(),
			)
			tgtfile = "{tgt_dir}/{prefix}/{filename}".format(
				prefix=prefix,
				filename=filename,
				tgt_dir=args.output_dir,
			)
			put_file(tgtfile, content=content)

			# accumulate per-prefix TF resources file
			tf_file = prefix + "/k8s_objects.tf"
			k8s_tf_files[tf_file] = k8s_tf_files.get(tf_file, "") + """
resource kubectl_generic_object {name}_{kind} {{
    yaml = "${{file("${{path.module}}/{filename}")}}"
}}
""".format(
				name=k8s_object['metadata']['name'].lower(),
				kind=k8s_object['kind'].lower(),
				filename=filename)
	# write out each module's tf file
	for path, content in k8s_tf_files.items():
		put_file(args.output_dir + "/" + path, content=content)


if __name__ == '__main__':
	main(parser.parse_args())
