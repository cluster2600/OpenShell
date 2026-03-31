#!/bin/sh

# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Regression tests for cluster-entrypoint.sh
#
# Validates that the entrypoint passes k3s flags correctly.
# These are static checks against the script text to catch regressions
# like the --resolv-conf removal in k3s v1.35.2 (see #696).
#
# Usage: sh deploy/docker/test-cluster-entrypoint.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTRYPOINT="$SCRIPT_DIR/cluster-entrypoint.sh"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ---- tests ------------------------------------------------------------------

echo "=== cluster-entrypoint.sh regression tests ==="
echo ""

# #696: k3s v1.35.2 removed the top-level --resolv-conf flag.
# It must be passed as --kubelet-arg=resolv-conf=<path>.
echo "--- resolv-conf flag (regression for #696) ---"

if grep -q -- '--kubelet-arg=resolv-conf=' "$ENTRYPOINT"; then
    pass "resolv-conf passed via --kubelet-arg"
else
    fail "resolv-conf must be passed as --kubelet-arg=resolv-conf=, not --resolv-conf="
fi

if grep -q -- ' --resolv-conf=' "$ENTRYPOINT"; then
    fail "top-level --resolv-conf= still present (removed in k3s v1.35.2)"
else
    pass "no top-level --resolv-conf= flag"
fi

# The exec line should use $RESOLV_CONF, not a hardcoded path.
if grep 'exec.*/bin/k3s' "$ENTRYPOINT" | grep -q '\$RESOLV_CONF'; then
    pass "exec line uses \$RESOLV_CONF variable"
else
    fail "exec line should reference \$RESOLV_CONF, not a hardcoded path"
fi

echo ""
echo "--- cgroup v1 compatibility ---"

# Cgroup v1 hosts need --kubelet-arg=fail-cgroupv1=false
if grep -q -- '--kubelet-arg=fail-cgroupv1=false' "$ENTRYPOINT"; then
    pass "cgroup v1 compatibility flag present"
else
    fail "missing --kubelet-arg=fail-cgroupv1=false for cgroup v1 hosts"
fi

echo ""
echo "--- DNS proxy setup ---"

# The RESOLV_CONF path should be defined
if grep -q '^RESOLV_CONF=' "$ENTRYPOINT"; then
    pass "RESOLV_CONF variable defined"
else
    fail "RESOLV_CONF variable not defined"
fi

# DNS proxy should write to RESOLV_CONF
if grep -q 'echo.*nameserver.*> "\$RESOLV_CONF"' "$ENTRYPOINT"; then
    pass "DNS proxy writes nameserver to \$RESOLV_CONF"
else
    fail "DNS proxy should write nameserver to \$RESOLV_CONF"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "FAILED: $FAILURES assertion(s)"
    exit 1
else
    echo "All tests passed."
fi
