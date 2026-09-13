#!/usr/bin/env bash
#
# Wrapper around `./apollo-ios-cli generate` that keeps this app pointed at the
# apollo-skip-fuse fork instead of upstream apollo-ios.
#
# The codegen `swiftPackage` module type always rewrites GitLabAPI/Package.swift
# to `.package(url: "https://github.com/apollographql/apollo-ios", exact: "2.4.0")`.
# Leaving that in place mixes upstream and forked copies of the same targets and
# fails with "multiple similar targets". This script restores the committed
# manifest after codegen and re-resolves, so generation cannot silently break the
# fork setup. (Package.resolved is gitignored here, hence the stale-pin guard.)
#
# Usage: scripts/generate.sh [apollo-ios-cli arguments...]
#   e.g. scripts/generate.sh -f    # fetch schema first, see the CLI's help
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

./apollo-ios-cli generate "$@"

# Restore the fork dependency that codegen just overwrote. The file is
# @generated; its committed version always carries the fork URL.
git checkout -- GitLabAPI/Package.swift

if ! grep -q 'felix-schindler/apollo-skip-fuse' GitLabAPI/Package.swift; then
  echo "error: GitLabAPI/Package.swift does not point at the fork after restore" >&2
  exit 1
fi

swift package resolve

# A resolve that ran against the generated manifest can leave an upstream pin
# behind. Fail loudly instead of silently mixing upstream and fork targets.
if grep -q 'github.com/apollographql/apollo-ios' Package.resolved; then
  echo "error: Package.resolved still contains an apollo-ios pin;" >&2
  echo "       remove Package.resolved and re-run to re-resolve cleanly" >&2
  exit 1
fi
