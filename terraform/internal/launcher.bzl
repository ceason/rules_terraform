
_LAUNCHER_TEMPLATE="""#!/usr/bin/env bash
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR
# find runfiles dir
if [[ -n "${TEST_SRCDIR-""}" && -d "$TEST_SRCDIR" ]]; then
  # use $TEST_SRCDIR if set.
  export RUNFILES="$TEST_SRCDIR"
elif [[ -z "${RUNFILES-""}" ]]; then
  # canonicalize the entrypoint.
  pushd "$(dirname "$0")" > /dev/null
  abs_entrypoint="$(pwd -P)/$(basename "$0")"
  popd > /dev/null
  if [[ -e "${abs_entrypoint}.runfiles" ]]; then
    # runfiles dir found alongside entrypoint.
    export RUNFILES="${abs_entrypoint}.runfiles"
  elif [[ "$abs_entrypoint" == *".runfiles/"* ]]; then
    # runfiles dir found in entrypoint path.
    export RUNFILES="${abs_entrypoint%%.runfiles/*}.runfiles"
  else
    >&2 echo "ERROR: Could not find runfiles directory."
    exit 1
  fi
fi
if [ -z "${PYTHON_RUNFILES-""}" ]; then
  export PYTHON_RUNFILES="$RUNFILES"
fi
ARGS=(
  %s
)
exec "${ARGS[@]}" "$@" <&0
"""

_runfiles_var_replacement_token="""!@#
Reserved token for replacing runfiles references.
#@!"""

def runfiles_path(ctx, f):
    """Return the runfiles relative path of f."""
    if ctx.workspace_name:
        return "${RUNFILES}/" + ctx.workspace_name + "/" + f.short_path
    else:
        return "${RUNFILES}/" + f.short_path

def create_launcher(ctx, output, args):
    """
    Writes a launcher to the specified output
    """
    resolved_args = []
    for arg in args:
        if type(arg) == "File":
            if ctx.workspace_name:
                arg_str = '${RUNFILES}/%s/%s' % (ctx.workspace_name, arg.short_path)
            else:
                arg_str = '${RUNFILES}/%s' % (arg.short_path)
        elif type(arg) == "string":
             arg_str = arg
        else:
            fail("Unknown argument type '%s' for arg '%s'" % (type(arg), arg))
        # escape double quotes & escape chars
        arg_str = arg_str.replace("\\", "\\\\")
        arg_str = arg_str.replace('"', '\\"')
        # escape '$' except for ${RUNFILES}
        arg_str = arg_str.replace('${RUNFILES}', _runfiles_var_replacement_token)
        arg_str = arg_str.replace('$', '\\$')
        arg_str = arg_str.replace(_runfiles_var_replacement_token, '${RUNFILES}')
        resolved_args.append('"%s"' % arg_str)
    launcher = _LAUNCHER_TEMPLATE % "\n  ".join(resolved_args)
    ctx.actions.write(output, launcher, is_executable = True)
