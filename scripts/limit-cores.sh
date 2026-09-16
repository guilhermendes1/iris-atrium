#!/usr/bin/env bash
#
# limit-cores.sh — Cap the CPU cores visible to the IRIS instance so the
# InterSystems IRIS Community Edition license (visible-core ceiling) is always
# satisfied on high-core hosts. Wraps a command in a taskset affinity mask,
# leaving low-core hosts untouched.
#
# Usage: limit-cores.sh <command> [args...]
# Env:   MP_MAX_CORES   Upper bound of visible cores (default 19; must be < 20).
#
set -u

MP_MAX_CORES_DEFAULT="19"
MP_MAX_CORES_MIN="1"
LICENSE_CORE_CEILING="20"

log() { printf '[mp] %s\n' "$*" >&2; }

if [ "$#" -lt 1 ]; then
  log "Usage: limit-cores.sh <command> [args...]"
  exit 2
fi

host_cores="$(nproc 2>/dev/null || true)"
if [ -z "$host_cores" ]; then
  log "Unable to detect the host CPU count; nproc is unavailable."
  exit 3
fi

max="${MP_MAX_CORES:-$MP_MAX_CORES_DEFAULT}"
case "$max" in
  ''|*[!0-9]*) max="$MP_MAX_CORES_DEFAULT" ;;
esac
if [ "$max" -ge "$LICENSE_CORE_CEILING" ]; then
  log "MP_MAX_CORES=$max must stay below the Community Edition ceiling ($LICENSE_CORE_CEILING). Clamping to $MP_MAX_CORES_DEFAULT."
  max="$MP_MAX_CORES_DEFAULT"
fi
if [ "$max" -lt "$MP_MAX_CORES_MIN" ]; then
  max="$MP_MAX_CORES_MIN"
fi

if [ "$host_cores" -le "$max" ]; then
  # Host already in bounds — run unconstrained; behavior is unchanged.
  exec "$@"
fi

if ! command -v taskset >/dev/null 2>&1; then
  log "The host exposes $host_cores cores (above MP_MAX_CORES=$max) but taskset is unavailable."
  log "Install util-linux in the image; the Community Edition license check will otherwise abort IRIS."
  exit 3
fi

core_range="0-$((max - 1))"
log "Capping IRIS to $max visible core(s); host exposes $host_cores (taskset -c $core_range)."
exec taskset -c "$core_range" "$@"