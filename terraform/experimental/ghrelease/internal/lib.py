from __future__ import print_function

import atexit
import logging
import os
import re
import shutil
import subprocess
from os import path
from subprocess import check_output
from tempfile import mkdtemp

import semver
import sys
from semver import VersionInfo
from typing import Union

# Use this env var to determine if this script was invoked w/ the appropriate bazel flags
BazelFlagsEnvVar = "RULES_TERRAFORM_GHRELEASE_BAZEL_FLAGS"


# def _run(args, **kwargs):
#     p = Popen(args, stdout=PIPE, stderr=PIPE,**kwargs)
#     out, err = p.communicate()


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
                 version_minor, hub_binary="hub"):
        self._docs_branch = docs_branch
        self._repo_dir = repo_dir
        self._branch = branch
        self._version_major = version_major
        self._version_minor = version_minor
        self._hub = path.abspath(hub_binary)

        remote = check_output(["git", "remote"], cwd=repo_dir).strip()
        self._remote_url = check_output(["git", "remote", "get-url", remote],
                                        cwd=repo_dir).strip()
        self._commit = check_output(
            ["git", "rev-parse", "--verify", "HEAD"],
            cwd=self._repo_dir).strip()

        self._repo_url = check_output([self._hub, "browse", "-u"], cwd=repo_dir).strip()
        # keep only parts of the URL we care about
        self._repo_url = "/".join(self._repo_url.split("/")[0:5])

        tags = {}
        self._heads = set()
        for line in check_output(["git", "ls-remote", "--tags", "--heads",
                                  self._remote_url], cwd=repo_dir).splitlines():
            if "\trefs/heads/" in line:
                commit, head = line.strip().split("\trefs/heads/")
                self._heads.add(head)
            if "\trefs/tags/" in line:
                commit, tag = line.strip().split("\trefs/tags/")
                tags[tag] = commit
        self._releases = []
        for line in check_output([self._hub, "release", "--format=%T %U"],
                                 cwd=self._repo_dir).splitlines():
            tag, url = line.strip().split(" ")
            commit = tags[tag]
            try:
                self._releases.append(ReleaseInfo(tag, url, commit))
            except ValueError:
                logging.warning("Could not parse '%s' as semver", tag)

    def get_next_semver(self, prerelease):
        return next_semver(self._version_major, self._version_minor,
                           prerelease, [v.tag for v in self._releases])

    def check_srcs_match_head(self, srcs):
        """
        check & report on: (aka "local" git checks, bc we resolve locally)
        - all source files are checked in (accumulate srcfiles while iterating tests/artifacts?)
        :param srcs:
        :return:
        """
        print("check_srcs_match_head() unimplemented")

    def check_local_tracks_authoritative_branch(self, publish):
        """
        remote tracking branch is the authoritative remote+branch (warning or err depends if we're publishing)
        :param publish:
        :return:
        """
        print("check_local_tracks_authoritative_branch() unimplemented")

    def check_head_exists_in_remote(self):
        """
        check HEAD commit exists in remote tracking branch
        - else push to remote
        :return:
        """
        try:
            print("check_head_exists_in_remote", end="...")
            sys.stdout.flush()
            sys.stderr.flush()
            subprocess.check_call(["git", "push"],
                                  cwd=self._repo_dir)
        except subprocess.CalledProcessError as e:
            exit(e.returncode)

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
        def _git(args):
            # type: (Union[str, list]) -> str
            from subprocess import PIPE
            import shlex
            cmd = ["git"]
            if type(args) in (str, unicode):
                cmd += shlex.split(args)
            else:
                cmd += args
            successful_exit_codes = {0}
            if "--exit-code" in cmd:
                successful_exit_codes.add(1)
            p = subprocess.Popen(cmd, stdout=PIPE, stderr=PIPE, cwd=tmpdir)
            out, err = p.communicate()
            rc = p.poll()
            if rc not in successful_exit_codes:
                print("Failed to exec cmd: " + " ".join(cmd), file=sys.stderr)
                if len(err) > 0:
                    print(err, file=sys.stderr)
                else:
                    print(out, file=sys.stderr)
                exit(rc)
            return out

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
        if self._docs_branch not in self._heads or _git(
            [worktree, "diff", "--exit-code",
             "remotes/origin/" + self._docs_branch]) == 1:
            # add,commit,push docs if there is a difference
            _git([worktree, "add", "-A"])
            _git("commit -m 'Updating docs.'")
            _git("push -u origin " + self._docs_branch)

        commit = _git("rev-parse --verify HEAD").strip()

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
            changelog += check_output([
                "git", "log",
                "--format=%s" % changelog_tpl.format(repo_url=self._repo_url),
                "%s..%s" % (from_commit, self._commit)
            ], cwd=self._repo_dir)
            output_parts.append(changelog)

        return "\n\n".join(output_parts)

    def publish_release(self, assets_dir, release_notes, tag, draft):
        hub_args = ["hub", "release", "create"]
        if draft:
            hub_args += ["--draft"]
        if "-" in tag:
            hub_args += ["--prerelease"]
        for root, dirs, files in os.walk(assets_dir):
            for f in files:
                hub_args += ["--attach=%s" % path.join(root, f)]
        hub_args += [tag]
        hub_args += ["--commitish=%s" % self._commit]
        hub_args += ["--message=%s\n\n%s" % (tag, release_notes)]
        if sys.stdout.isatty():
            hub_args.append("--browse")

        rc = subprocess.call(hub_args, cwd=self._repo_dir)
        if rc != 0:
            exit(rc)
        # get the new tag (if this wasn't a draft)
        if not draft:
            subprocess.call(["git", "fetch", "--tags"], cwd=self._repo_dir)
