#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
#
# One-shot helper to set the GitHub repo description and topics via the
# REST API. Avoids needing `gh` CLI for a single-use configuration.
#
# Usage:
#   GH_TOKEN=ghp_xxxxxxxx ./scripts/configure-github-repo.sh
#
# Get a token at: https://github.com/settings/tokens/new
#   - Scope needed: "repo" (or fine-grained: "Administration: read & write"
#     on this single repo)
#   - Expiry: 7 days is fine — you can delete it right after.
#
# After running, delete the token at https://github.com/settings/tokens

set -euo pipefail

REPO="EnginKarahan/claude_usage_monitor"
DESCRIPTION="Unofficial KDE Plasma 6 widget showing Claude.ai session and weekly token usage with reset forecast"
HOMEPAGE="https://github.com/$REPO"
TOPICS=(kde-plasma plasmoid plasma6 claude monitoring python qml taskbar widget anthropic)

: "${GH_TOKEN:?Set GH_TOKEN to your GitHub Personal Access Token (scope: repo)}"

api() {
    curl --fail-with-body -sS \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$@"
}

echo "▶ Setting description and homepage"
api -X PATCH "https://api.github.com/repos/$REPO" \
    -d "$(jq -n --arg d "$DESCRIPTION" --arg h "$HOMEPAGE" \
        '{description: $d, homepage: $h, has_issues: true, has_wiki: false}')" \
    > /dev/null

echo "▶ Setting topics: ${TOPICS[*]}"
api -X PUT "https://api.github.com/repos/$REPO/topics" \
    -d "$(jq -n --argjson names "$(printf '%s\n' "${TOPICS[@]}" | jq -R . | jq -s .)" \
        '{names: $names}')" \
    > /dev/null

echo "✓ Done. Open https://github.com/$REPO to verify."
echo "  Remember to delete the token: https://github.com/settings/tokens"
