from __future__ import print_function

import unittest
from random import shuffle

from lib import next_semver


class TestNextSemver(unittest.TestCase):
    def test(self):
        vs = [
            # no prereleases
            "v1.6.0",
            "v1.6.1",

            # only prereleases
            "v1.7.1-beta.1",
            "v1.7.1-alpha.0",
            "v1.7.1-rc.3",

            # pre and releases
            "v1.8.0",
            "v1.8.1",
            "v1.8.1-beta.1",
            "v1.8.1-alpha.0",
            "v1.8.1-rc.3",
        ]
        shuffle(vs)

        # new prerelease
        self.assertEqual(next_semver(1, 6, "alpha", vs), "v1.6.2-alpha.0")

        # next prerelease
        self.assertEqual(next_semver(1, 7, "beta", vs), "v1.7.1-beta.2")

        # next release
        self.assertEqual(next_semver(1, 6, versions=vs), "v1.6.2")
        self.assertEqual(next_semver(1, 7, versions=vs), "v1.7.1")
        self.assertEqual(next_semver(1, 8, versions=vs), "v1.8.2")

        # new release
        self.assertEqual(next_semver(1, 9, versions=vs), "v1.9.0")

        # no existing versions
        self.assertEqual(next_semver(1, 6, "alpha"), "v1.6.0-alpha.0")


if __name__ == '__main__':
    unittest.main()
