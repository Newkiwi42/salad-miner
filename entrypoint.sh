#!/usr/bin/env bash
# Maps simple env vars (WORKER / POOL / ADDRESS) onto miner command lines.
set -euo pipefail

# --- Required -------------------------------------------------------------
: "${POOL:?POOL is required, e.g. stratum+tcp://pool.example.com:3333}"
: "${ADDRESS:?ADDRESS (wallet address) is required}"

# --- Optional -------------------------------------------------------------
# WORKER defaults to the Salad machine id so every node shows up separately.
WORKER="${WORKER:-${SALAD_MACHINE_ID:-salad}}"
MINER="${MINER:-srbminer}"          # srbminer | lolminer | xmrig
ALGO="${ALGO:-pearlhash}"           # default: Pearl (PRL)
PASSWORD="${PASSWORD:-x}"           # pool password field
WORKER_SEP="${WORKER_SEP:-.}"       # most pools use ADDRESS.WORKER
EXTRA_ARGS="${EXTRA_ARGS:-}"        # anything else, passed straight through

# Salad replicas share one config, so give each a unique suffix if asked.
if [[ "${WORKER_APPEND_MACHINE_ID:-false}" == "true" && -n "${SALAD_MACHINE_ID:-}" ]]; then
  WORKER="${WORKER}-${SALAD_MACHINE_ID:0:8}"
fi

USER_STR="${ADDRESS}${WORKER_SEP}${WORKER}"

echo "Miner:   ${MINER}"
echo "Algo:    ${ALGO}"
echo "Pool:    ${POOL}"
echo "Address: ${ADDRESS}"
echo "Worker:  ${WORKER}"

# PearlHash is a GPU algorithm, so keep the CPU idle (set GPU_ONLY=false to override).
SRB_GPU_ONLY=""
if [[ "${GPU_ONLY:-true}" == "true" && "${ALGO,,}" == "pearlhash" ]]; then
  SRB_GPU_ONLY="--disable-cpu"
fi

# shellcheck disable=SC2086
case "${MINER,,}" in
  lolminer)
    exec /opt/miners/lolminer/lolMiner \
      --algo "${ALGO}" \
      --pool "${POOL}" \
      --user "${USER_STR}" \
      --pass "${PASSWORD}" \
      ${EXTRA_ARGS}
    ;;
  xmrig)
    exec /opt/miners/xmrig/xmrig \
      --algo "${ALGO}" \
      --url "${POOL}" \
      --user "${USER_STR}" \
      --pass "${PASSWORD}" \
      --rig-id "${WORKER}" \
      --donate-level 1 \
      --no-color \
      ${EXTRA_ARGS}
    ;;
  srbminer)
    exec /opt/miners/srbminer/SRBMiner-MULTI \
      --algorithm "${ALGO}" \
      --pool "${POOL}" \
      --wallet "${ADDRESS}" \
      --worker "${WORKER}" \
      --password "${PASSWORD}" \
      --disable-startup-monitor \
      ${SRB_GPU_ONLY} \
      ${EXTRA_ARGS}
    ;;
  *)
    echo "Unknown MINER '${MINER}'. Use lolminer, xmrig or srbminer." >&2
    exit 1
    ;;
esac
