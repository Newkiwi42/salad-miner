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

# TLS: auto turns it on for ssl/tls pool URLs and port 443.
TLS="${TLS:-auto}"
if [[ "${TLS}" == "auto" ]]; then
  if [[ "${POOL,,}" =~ ^(stratum\+ssl|stratum\+tls|ssl|tls):// || "${POOL}" =~ :443/?$ ]]; then
    TLS=true
  else
    TLS=false
  fi
fi

echo "Miner:   ${MINER}"
echo "Algo:    ${ALGO}"
echo "Pool:    ${POOL}"
echo "TLS:     ${TLS}"
echo "Address: ${ADDRESS}"
echo "Worker:  ${WORKER}"

# Show which GPUs the container can see, so a missing GPU is obvious in the logs.
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -L || echo "nvidia-smi failed: the container cannot reach the GPU driver"
else
  echo "nvidia-smi not found: no NVIDIA driver was mounted into this container"
fi

# PearlHash is a GPU algorithm, so keep the CPU idle (set GPU_ONLY=false to override).
SRB_GPU_ONLY=""
if [[ "${GPU_ONLY:-true}" == "true" && "${ALGO,,}" == "pearlhash" ]]; then
  SRB_GPU_ONLY="--disable-cpu"
fi

# If the miner stops, wait before exiting so the reason stays readable in the
# Salad logs instead of being buried by rapid restarts.
fail() {
  echo "Miner stopped (exit $1). Restarting in ${RESTART_DELAY:-30}s."
  sleep "${RESTART_DELAY:-30}"
  exit 1
}

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
    # SRBMiner wants host:port plus --tls, not a stratum+...:// URL.
    SRB_POOL="${POOL#*://}"
    SRB_CMD=(/opt/miners/srbminer/SRBMiner-MULTI
      --algorithm "${ALGO}"
      --pool "${SRB_POOL}"
      --tls "${TLS}"
      --wallet "${ADDRESS}"
      --worker "${WORKER}"
      --password "${PASSWORD}"
      --disable-startup-monitor
      ${SRB_GPU_ONLY}
      ${EXTRA_ARGS})
    # SRBMiner prints nothing without a terminal, so run it under `script` to
    # give it one. If it rejects the settings it drops into an interactive
    # setup prompt; catch that and stop instead of looping forever.
    set +e
    script -qfec "$(printf '%q ' "${SRB_CMD[@]}")" /dev/null </dev/null \
      | sed -u 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' \
      | awk '/Guided setup/ { print "SRBMiner rejected the settings (check POOL, ADDRESS and ALGO)"; exit 2 }
             NF { print; fflush() }'
    codes=("${PIPESTATUS[@]}")
    set -e
    [[ "${codes[2]}" == 2 ]] && fail 2
    fail "${codes[0]}"
    ;;
  *)
    echo "Unknown MINER '${MINER}'. Use lolminer, xmrig or srbminer." >&2
    exit 1
    ;;
esac
