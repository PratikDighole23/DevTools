// ...existing code...
# CockroachDB — Installation and quick start

This document contains concise, tested steps to run CockroachDB locally on macOS (Homebrew) and via Docker. Notes include recommended checks and small operational tips.

## Important notes
- These examples use --insecure for local testing only. Do NOT use --insecure in production.
- Adjust versions, ports and volume names to avoid conflicts on your machine.
- On macOS, ensure Homebrew and Docker Desktop are installed and up to date.

## Binary (macOS / Homebrew)
1. Install:
```bash
brew install cockroachdb/tap/cockroach
```

2. Start a three-node local cluster (example ports shown; run three terminals or background each):
```bash
# Node 1
cockroach start \
  --insecure \
  --store=node1 \
  --listen-addr=localhost:26257 \
  --http-addr=localhost:8080 \
  --join=localhost:26257,localhost:26258,localhost:26259 \
  --background

# Node 2
cockroach start \
  --insecure \
  --store=node2 \
  --listen-addr=localhost:26258 \
  --http-addr=localhost:8081 \
  --join=localhost:26257,localhost:26258,localhost:26259 \
  --background

# Node 3
cockroach start \
  --insecure \
  --store=node3 \
  --listen-addr=localhost:26259 \
  --http-addr=localhost:8082 \
  --join=localhost:26257,localhost:26258,localhost:26259 \
  --background
```

3. Initialize cluster and access SQL:
```bash
cockroach init --insecure --host=localhost:26257
cockroach sql  --insecure --host=localhost:26257
cockroach node status --insecure --host=localhost:26257
cockroach node drain <node-id> --insecure --host=localhost:26257
```

## Docker (recommended for isolated local testing)
- Set version variable to control the image used:
```bash
CRDB_IMAGE="cockroachdb/cockroach:v26.2.1"
```

1. Create network and volumes:
```bash
docker network create -d bridge roachnet
docker volume create roach1
docker volume create roach2
docker volume create roach3
```

2. Start three containers (example exposes one public SQL port per container and web UI ports):
```bash
docker run -d \
  --name=roach1 \
  --hostname=roach1 \
  --net=roachnet \
  -p 26257:26257 -p 8080:8080 \
  -v roach1:/cockroach/cockroach-data \
  $CRDB_IMAGE start --insecure --join=roach1,roach2,roach3

docker run -d \
  --name=roach2 \
  --hostname=roach2 \
  --net=roachnet \
  -p 26258:26257 -p 8081:8080 \
  -v roach2:/cockroach/cockroach-data \
  $CRDB_IMAGE start --insecure --join=roach1,roach2,roach3

docker run -d \
  --name=roach3 \
  --hostname=roach3 \
  --net=roachnet \
  -p 26259:26257 -p 8082:8080 \
  -v roach3:/cockroach/cockroach-data \
  $CRDB_IMAGE start --insecure --join=roach1,roach2,roach3
```

3. Initialize and verify:
```bash
docker container ls
docker exec -it roach1 ./cockroach init --insecure
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257
docker exec -it roach1 grep 'node starting' cockroach-data/logs/cockroach.log -A 11
```

4. Stop and clean up:
```bash
docker stop roach1 roach2 roach3
docker rm roach1 roach2 roach3
docker network rm roachnet
docker volume rm roach1 roach2 roach3
# If you mounted host paths, remove host data directories carefully:
# rm -rf /path/to/cockroach-data
```

## Troubleshooting & tips
- If nodes fail to join, check container hostnames and the --join parameter for typos.
- Use distinct ports on the host to avoid conflicts if multiple clusters run locally.
- For production, follow CockroachDB TLS and secure cluster setup guide — do not use --insecure.
- Use the built-in admin UI (http://localhost:8080, 8081, 8082) to inspect cluster health and metrics.
- On macOS, Docker Desktop's resource limits (CPU/RAM) can impact cluster startup; increase them if pods fail.
- To run a single-node quickstart for development, you can start one Cockroach instance without explicit --join.

## References
- Official docs: https://www.cockroachlabs.com/docs/
- Secure deployment guide: https://www.cockroachlabs.com/docs/stable/secure-a-cluster.html

// ...existing code...