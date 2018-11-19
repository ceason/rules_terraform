from __future__ import print_function

import atexit
import logging
import os
import re
import shlex
import shutil
import subprocess
from os import path
from subprocess import CalledProcessError
from tempfile import mkdtemp

import semver
import sys
from semver import VersionInfo
from typing import Union

# Use this env var to determine if this script was invoked w/ the appropriate bazel flags
BazelFlagsEnvVar = "RULES_TERRAFORM_GHRELEASE_BAZEL_FLAGS"


def next_semver(major, minor, prerelease=None, versions=None):
    # type: (int, int, str, list) -> str
    major = int(major)
    minor = int(minor)

    def stuff_we_care_about(v):
        """
        we only care about stuff that:
        - has our same major+minor version
        - is a release OR has our same prerelease token
        """
        if v.major != major:
            return False
        if v.minor != minor:
            return False
        if not prerelease:
            return True
        if v.prerelease is None:
            return True
        prefix = prerelease + "."
        if v.prerelease.startswith(prefix):
            # also needs to end in an int for us to care about it
            return bool(re.match("^\d+$", v.prerelease[len(prefix):]))
        return False

    semvers = [
        VersionInfo.parse(v[1:] if v.startswith("v") else v)
        for v in versions or []
    ]
    semvers = filter(stuff_we_care_about, semvers)
    if semvers:
        latest = sorted(semvers)[-1]
        version = str(latest)
        # do we bump patch?
        if not latest.prerelease:
            version = semver.bump_patch(version)
        # is this a final version?
        if prerelease:
            version = semver.bump_prerelease(version, prerelease)
        else:
            version = semver.finalize_version(version)
    else:
        # nothing exists on the current minor version so create a new one
        version = "%s.%s.0" % (major, minor)
        if prerelease:
            version += "-%s.1" % prerelease
    return "v" + version


class SubprocessHelper(object):

    def __init__(self, args=None, chomp_output=False, **popen_kwargs):
        """
        Set defaults for calling a subprocess.
        :param args: Will be prepended to all invocations.
        :param chomp_output: Remove trailing newline from output.
        :param popen_kwargs: Default kwargs for subprocess.Popen
        :return:
        """
        self._chomp_output = chomp_output
        self._rc = None
        if type(args) in (str, unicode):
            args = shlex.split(args)
        self._args = args or []
        if 'stdout' not in popen_kwargs:
            popen_kwargs['stdout'] = subprocess.PIPE
        if 'stderr' not in popen_kwargs:
            popen_kwargs['stderr'] = subprocess.PIPE
        self._popen_kwargs = popen_kwargs

    def __call__(self, args, chomp_output=None, success_exit_codes=None, **kwargs):
        # type: (Union[list,str], bool, list[int], dict) -> str
        """
        Execute the provided command and return its output.
        :rtype: str
        :param args: Will be appended to the default args & executed
        :param chomp_output: Remove trailing newline from output.
        :param success_exit_codes: Do not raise an exception when process returns these codes.
        :param kwargs: passed through to subprocess.Popen
        :return: 
        """
        success_exit_codes = success_exit_codes or {0}
        if type(args) in (str, unicode):
            args = shlex.split(args)
        args = self._args + args
        # add defaults
        for k, v in self._popen_kwargs.items():
            if k not in kwargs:
                kwargs[k] = v
        p = subprocess.Popen(args, **kwargs)
        out, err = p.communicate()  # type: (str, str)
        rc = p.wait()
        self._rc = rc
        if rc not in success_exit_codes:
            raise CalledProcessError(rc, " ".join(args), output=err or out)
        chomp = self._chomp_output if chomp_output is None else chomp_output
        if chomp and out:
            return out.rstrip("\r\n")
        else:
            return out

    @property
    def returncode(self):
        # type: () -> int
        """
        :return: Exit code of most recently executed command.
        """
        return self._rc


class ReleaseInfo(VersionInfo):
    __slots__ = ('url', 'commit', 'tag')

    def __init__(self, tag, url, commit):
        super(ReleaseInfo, self).__init__(**semver.parse(
            tag[1:] if tag.startswith('v') else tag))
        self.tag = tag
        self.url = url
        self.commit = commit


class GhHelper:

    def __init__(self, repo_dir, branch, docs_branch, version_major,
                 version_minor, hub_binary=None):

        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._version_major = version_major
        self._version_minor = version_minor

        git = SubprocessHelper('git', chomp_output=True, cwd=repo_dir)
        hub = SubprocessHelper(path.abspath(hub_binary) if hub_binary else "hub",
                               chomp_output=True, cwd=repo_dir)
        self._hub = hub
        self._git = git

        remote = git("remote")
        self._remote_url = git('remote get-url ' + remote)
        self._commit = git('rev-parse --verify HEAD')
        self._repo_url = hub('browse -u')
        # keep only parts of the URL we care about
        self._repo_url = "/".join(self._repo_url.split("/")[0:5])

        tags = {}
        self._heads = set()
        for line in git('ls-remote --tags --heads ' +
                        self._remote_url).splitlines():
            if "\trefs/heads/" in line:
                commit, head = line.strip().split("\trefs/heads/")
                self._heads.add(head)
            if "\trefs/tags/" in line:
                commit, tag = line.strip().split("\trefs/tags/")
                tags[tag] = commit
        self._releases = []
        for line in hub('release --format="%T %U"').splitlines():
            tag, url = line.split(" ")
            commit = tags[tag]
            try:
                self._releases.append(ReleaseInfo(tag, url, commit))
            except ValueError:
                logging.warning("Could not parse '%s' as semver", tag)

    def get_next_semver(self, prerelease):
        return next_semver(self._version_major, self._version_minor,
                           prerelease, [v.tag for v in self._releases])

    def check_srcs_match_head(self, srcs, publish):
        """
        (warning or err depends if we're publishing)
        check & report on: (aka "local" git checks, bc we resolve locally)
        - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
        :param srcs:
        :return:
        """
        print("check_srcs_match_head ...Unimplemented :(")

    def check_local_tracks_authoritative_branch(self, publish):
        """
        remote tracking branch is the authoritative remote+branch (warning or err depends if we're publishing)
        :param publish:
        :return:
        """
        head_ref = self._git('symbolic-ref -q HEAD')
        tracked_branch = self._git([
            'for-each-ref',
            '--format=%(upstream:lstrip=3)',
            head_ref])
        print("check_local_tracks_authoritative_branch", end=" ...")
        if tracked_branch != self._branch:
            print("FAILED")
            msg = "Local branch does not track authoritative branch '%s'" % self._branch
            if publish:
                print("FATAL: %s" % msg, file=sys.stderr)
                exit(1)
            else:
                print("WARNING: %s (this will prevent publishing)" % msg, file=sys.stderr)
        else:
            print("OK")

    def check_head_exists_in_remote(self):
        """
        check HEAD commit exists in remote tracking branch
        - else push to remote
        :return:
        """
        print("check_head_exists_in_remote", end=" ...")
        sys.stdout.flush()
        sys.stderr.flush()
        self._git('push')
        print("OK")

    def publish_docs(self, docs_dir):
        links = []
        for root, dirs, files in os.walk(docs_dir):
            for f in files:
                abspath = path.normpath(path.join(root, f))
                relpath = abspath[len(docs_dir) + 1:]
                links.append("{repo_url}/blob/{commit}/" + relpath)

        # short-circuit if there's nothing to do
        if len(links) == 0 and self._docs_branch not in self._heads:
            return []

        # create temp dir
        tmpdir = mkdtemp()
        atexit.register(shutil.rmtree, tmpdir, ignore_errors=True)

        # convenience wrapper
        # - runs git in tmpdir
        # - exits with message if there's a problem
        # - returns process returncode otherwise

        _git = SubprocessHelper('git', chomp_output=True, cwd=tmpdir)

        if self._docs_branch in self._heads:
            # shallow clone docs branch if it exists
            _git(["clone", "--depth", "1",
                  "-b", self._docs_branch,
                  "--", self._remote_url, tmpdir])
        else:
            # else init empty repo
            _git("init")
            _git("checkout -b " + self._docs_branch)
            _git("remote add origin " + self._remote_url)

        # check difference between docs dir and docs branch
        worktree = "--work-tree=%s" % docs_dir

        def has_changes():
            _git([worktree, "diff", "--exit-code",
                  "remotes/origin/" + self._docs_branch],
                 success_exit_codes=[0, 1])
            return _git.returncode == 1

        if self._docs_branch not in self._heads or has_changes():
            # add,commit,push docs if there is a difference
            _git([worktree, "add", "-A"])
            _git("commit -m 'Updating docs.'")
            _git("push -u origin " + self._docs_branch)

        commit = _git("rev-parse --verify HEAD")

        return [l.format(
            commit=commit,
            repo_url=self._repo_url,
        ) for l in links]

    def generate_releasenotes(self, docs_links=None, asset_srcs=None):
        # type: (list, set) -> str
        """
        :param docs_links: List of links to docs associated with this release
        :param asset_srcs: (Unimplemented) Set of files. The changelog will
        be filtered to include only commits which involve these files.
        :return:
        """
        changelog_tpl = "- [`%h`]({repo_url}/commit/%H) %s"
        docs_tpl = """### Docs
{links}"""

        from_tag = None
        from_commit = None
        # find latest release (for our MAJOR.MINOR version)
        # - get all releases, latest to earliest
        # - return first release that has <= MAJOR and <= MINOR versions
        for r in sorted(self._releases, reverse=True):
            if r.major <= self._version_major and r.minor <= self._version_minor:
                from_tag = r.tag
                from_commit = r.commit

        output_parts = []
        if docs_links:
            docs_links_md = [
                "- [{filename}]({url})".format(
                    filename=l.split('/')[-1],
                    url=l)
                for l in docs_links
            ]
            output_parts.append(docs_tpl.format(
                links="\n".join(docs_links_md)))

        if from_commit:
            changelog = "### Changes Since `%s`:\n" % from_tag
            changelog += self._git([
                "log",
                "--format=%s" % changelog_tpl.format(repo_url=self._repo_url),
                "%s..%s" % (from_commit, self._commit)
            ])
            output_parts.append(changelog)

        return "\n\n".join(output_parts)

    def publish_release(self, assets_dir, release_notes, tag, draft):
        args = ["release", "create"]
        if draft:
            args += ["--draft"]
        if "-" in tag:
            args += ["--prerelease"]
        for root, dirs, files in os.walk(assets_dir):
            for f in files:
                args += ["--attach=%s" % path.join(root, f)]
        args += [tag]
        args += ["--commitish=%s" % self._commit]
        args += ["--message=%s\n\n%s" % (tag, release_notes)]
        if sys.stdout.isatty():
            args.append("--browse")

        self._hub(args, stdout=sys.stdout, stderr=sys.stderr)
        # get the new tag (if this wasn't a draft)
        if not draft:
            try:
                self._git('fetch --tags')
            except CalledProcessError as e:
                logging.warning("Could not pull tags after publishing: %s", str(e))
