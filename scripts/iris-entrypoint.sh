#!/usr/bin/env bash
#
# iris-entrypoint.sh — Entrypoint override for the IRIS Atrium image.
# Applies the Community Edition core cap, then hands off to the stock /iris-main
# entrypoint with all original arguments preserved (e.g. --check-caps false).
#
set -eu

exec /bin/bash /usr/local/bin/limit-cores.sh /iris-main "$@"