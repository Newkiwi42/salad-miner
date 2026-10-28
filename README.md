# salad-miner

A Docker mining image for SaladCloud, set up with simple environment variables.
By default it mines **Pearl (PRL)** with SRBMiner-Multi on NVIDIA GPUs (algorithm `pearlhash`).

## Environment variables

| Variable | Required | Example | Notes |
|---|---|---|---|
| `POOL` | yes | `stratum+tcp://us.nushypool.com:40015` | Pearl pool URL |
| `ADDRESS` | yes | `prl1...` | Pearl wallet address (starts with `prl1`) |
| `WORKER` | no | `salad01` | Defaults to `SALAD_MACHINE_ID` (Salad sets this itself) |
| `MINER` | no | `srbminer` | `srbminer` (default), `lolminer`, `xmrig` |
| `ALGO` | no | `pearlhash` | Default `pearlhash` (PRL). Change it only if you switch coins |
| `GPU_ONLY` | no | `true` | Adds `--disable-cpu` for pearlhash so the CPU stays idle |
| `PASSWORD` | no | `x` | Pool password field |
| `WORKER_SEP` | no | `.` | Separator in `ADDRESS.WORKER` (some pools want `/` or `_`) |
| `WORKER_APPEND_MACHINE_ID` | no | `true` | Adds the first 8 chars of the machine id, so replicas get unique names |
| `EXTRA_ARGS` | no | `--apiport 4068` | Extra flags passed straight to the miner |

## Build and push

```bash
docker build -t YOURDOCKERHUB/salad-miner:latest .
docker push YOURDOCKERHUB/salad-miner:latest
```

## Test locally (NVIDIA GPU)

```bash
docker run --rm --gpus all -e POOL=stratum+tcp://us.nushypool.com:40015 -e ADDRESS=prl1YourWallet -e WORKER=test YOURDOCKERHUB/salad-miner:latest
```

## SaladCloud setup

1. Portal → Container Groups → Create.
2. Image source: `YOURDOCKERHUB/salad-miner:latest`.
3. Environment variables: add `WORKER`, `POOL`, `ADDRESS`.
4. Pick an NVIDIA RTX 3000/4000/5000 GPU class, replica count, and start. No networking or health probe is needed.
5. Check the container logs in the portal to confirm shares are accepted.

Tip: with several replicas, set `WORKER=salad` and `WORKER_APPEND_MACHINE_ID=true` so each node shows up as its own worker on the pool.
