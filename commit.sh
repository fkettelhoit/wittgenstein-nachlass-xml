#!/bin/sh
set -u

git config --global user.name "${GITHUB_ACTOR}" \
&& git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com" \
&& git commit -am 'Auto-commit' --author="${COMMIT_AUTHOR}" \
; git push -u origin HEAD
