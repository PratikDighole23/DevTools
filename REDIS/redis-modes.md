# Redis Deployment Modes: Standalone, Sentinel, and Cluster

## Overview

Redis can be deployed in three primary modes:

1. **Standalone Mode** – Single Redis instance
2. **Sentinel Mode** – High Availability with automatic failover
3. **Cluster Mode** – High Availability + Horizontal Scaling

Understanding the differences between these modes is essential when designing reliable and scalable applications.

---

# 1. Redis Standalone Mode

## What is Redis Standalone?

Redis Standalone is the simplest deployment model where a single Redis server stores all data.

### Architecture

```text
Application
     |
     v
+------------+
| Redis Node |
+------------+
```

---

## Characteristics

* Single Redis instance
* No data sharding
* No automatic failover
* Easy to set up and manage
* Suitable for development and small workloads

---

## Advantages

* Simple configuration
* Minimal operational overhead
* Low latency

---

## Limitations

* Single point of failure
* No horizontal scaling
* Limited by resources of one server

---

## Example Configuration

```bash
redis-server redis.conf
```

Application connection:

```properties
redis.host=10.0.0.10
redis.port=6379
```

---

## Use Cases

* Local development
* Testing environments
* Small applications
* Caching with acceptable downtime

---

# 2. Redis Sentinel Mode

## What is Redis Sentinel?

Redis Sentinel provides High Availability (HA) for Redis.

Sentinel continuously monitors Redis instances and automatically performs failover when a master becomes unavailable.

---

## Architecture

```text
                   +----------------+
                   |   Sentinel 1   |
                   +----------------+
                           |
                           |
+-------------+     +-------------+     +-------------+
| Replica 1   |<--->|   Master    |<--->| Replica 2   |
+-------------+     +-------------+     +-------------+
                           |
                   +----------------+
                   |   Sentinel 2   |
                   +----------------+

                   +----------------+
                   |   Sentinel 3   |
                   +----------------+
```

---

## Components

### Master

Handles:

* Reads
* Writes

### Replicas

Maintain copies of master data.

Can optionally serve read requests.

### Sentinel Nodes

Responsible for:

* Monitoring Redis nodes
* Detecting failures
* Electing a new master
* Notifying applications

---

## Failover Process

### Before Failure

```text
Master
  |
  +--> Replica 1
  |
  +--> Replica 2
```

### Master Failure

```text
Master (DOWN)
```

Sentinels detect failure.

### After Failover

```text
Replica 1 promoted to Master

New Master
   |
   +--> Replica 2
```

---

## Application Connection

Applications connect using Sentinel-aware clients.

Example:

```properties
sentinel.nodes=10.0.0.1:26379,10.0.0.2:26379,10.0.0.3:26379
master.name=mymaster
```

Client asks Sentinel:

```text
Who is the current master?
```

Sentinel returns current master address.

---

## Advantages

### High Availability

Automatic failover.

### Simplicity

No data partitioning.

### Full Dataset Available

Entire dataset remains on a single master.

---

## Limitations

### No Horizontal Scaling

All data still resides on one master.

### Memory Bound

Dataset size limited by master server capacity.

---

## Use Cases

* Production caching
* Session storage
* Medium-sized applications
* Applications requiring automatic failover

---

# 3. Redis Cluster Mode

## What is Redis Cluster?

Redis Cluster provides:

* High Availability
* Automatic Failover
* Horizontal Scaling
* Data Sharding

It distributes data across multiple Redis masters.

---

## Architecture

```text
                Application
                      |
          -------------------------
          |          |            |
          v          v            v

      Master 1   Master 2   Master 3
         |          |          |
         v          v          v
      Replica1   Replica2   Replica3
```

---

## Key Difference from Sentinel

### Sentinel

```text
One master stores all data
```

### Cluster

```text
Multiple masters store portions of data
```

---

# Redis Cluster Data Distribution

Redis Cluster distributes data using hash slots.

---

## Hash Slots

Redis defines:

```text
16384 hash slots
```

Range:

```text
0 - 16383
```

Every key belongs to one slot.

---

## Slot Calculation

For every key:

```text
hash_slot = CRC16(key) % 16384
```

Example:

```text
Key: user:123
```

Suppose:

```text
CRC16(user:123) % 16384 = 7421
```

Then slot:

```text
7421
```

---

## Slot Assignment

Example cluster:

| Master Node | Slot Range    |
| ----------- | ------------- |
| Master 1    | 0 - 5000      |
| Master 2    | 5001 - 10000  |
| Master 3    | 10001 - 16383 |

---

## Storage Example

Application writes:

```redis
SET user:123 "Pratik"
```

Steps:

```text
1. Calculate slot
2. Determine slot owner
3. Route request
4. Store data
```

Example:

```text
user:123
      ↓
slot 7421
      ↓
Master 2
      ↓
Stored on Master 2
```

---

# How Clients Find the Correct Node

Redis Cluster uses client-side routing.

---

## Cluster Discovery

Application connects to any cluster node.

Client executes:

```redis
CLUSTER SLOTS
```

Response contains:

```text
Slot ranges
Node addresses
Replica information
```

Client caches this mapping.

---

## Request Flow

```text
Application
     |
     v
Redis Client
     |
     +--> Hash Key
     |
     +--> Calculate Slot
     |
     +--> Find Node
     |
     +--> Send Request
```

---

## MOVED Redirection

If request reaches the wrong node:

```text
-MOVED 7421 10.0.0.2:6379
```

Client:

```text
Updates topology
Retries request
```

Automatically.

---

# Cluster Metadata

Each node stores cluster information.

File:

```text
nodes.conf
```

Contains:

* Node IDs
* IP addresses
* Port numbers
* Slot ownership
* Replica mappings

---

# Cluster Commands

View slots:

```bash
redis-cli -c -h <host> -p <port> CLUSTER SLOTS
```

View cluster nodes:

```bash
redis-cli -c -h <host> -p <port> CLUSTER NODES
```

Cluster status:

```bash
redis-cli --cluster check <host>:6379
```

---

# Hash Tags

Hash tags force related keys into the same slot.

---

## Syntax

```text
{...}
```

Example:

```redis
SET user:{123}:name "Pratik"
SET user:{123}:email "abc@test.com"
```

Only:

```text
123
```

is hashed.

Both keys end up in the same slot.

---

## Why Hash Tags Matter

Required for:

* Transactions (MULTI/EXEC)
* Lua Scripts
* Multi-key operations
* Atomic operations

---

# Cluster Failover

Each master should have at least one replica.

Example:

```text
Master 1
   |
Replica 1
```

If Master 1 fails:

```text
Replica 1 promoted to Master
```

Cluster continues serving requests.

---

# Comparison of Redis Modes

| Feature                | Standalone    | Sentinel      | Cluster          |
| ---------------------- | ------------- | ------------- | ---------------- |
| High Availability      | No            | Yes           | Yes              |
| Automatic Failover     | No            | Yes           | Yes              |
| Horizontal Scaling     | No            | No            | Yes              |
| Data Sharding          | No            | No            | Yes              |
| Multiple Masters       | No            | No            | Yes              |
| Operational Complexity | Low           | Medium        | High             |
| Dataset Size Limit     | Single Server | Single Server | Multiple Servers |
| Production Suitable    | Limited       | Yes           | Yes              |

---

# Which Mode Should You Choose?

## Choose Standalone When

* Development environment
* Small workloads
* Simplicity is preferred

---

## Choose Sentinel When

* Need High Availability
* Dataset fits on one server
* No sharding required

---

## Choose Cluster When

* Large datasets
* High throughput requirements
* Horizontal scaling required
* High availability required

---

# Typical Production Recommendations

### Small Applications

```text
Standalone
```

### Medium Applications

```text
Master + Replicas + Sentinel
```

### Large Scale Systems

```text
Redis Cluster
```

Recommended:

```text
3 Masters
3 Replicas
```

Minimum production-grade cluster:

```text
6 Nodes
```

---

# End-to-End Cluster Flow

```text
Application Starts
       |
       v
Connect to Cluster Node
       |
       v
Fetch Cluster Topology
(CLUSTER SLOTS)
       |
       v
Key -> CRC16 Hash
       |
       v
Hash Slot (0-16383)
       |
       v
Determine Slot Owner
       |
       v
Send Request To Correct Master
       |
       v
Store/Retrieve Data
       |
       v
Replica Synchronization
```

---

# Key Takeaways

* Redis Standalone is simple but has no failover.
* Redis Sentinel adds automatic failover and high availability.
* Redis Cluster adds both failover and horizontal scaling.
* Redis Cluster distributes keys using 16384 hash slots.
* Slot ownership determines where data is stored.
* Cluster-aware clients perform request routing.
* Hash tags allow related keys to stay on the same node.
* Cluster mode is the preferred solution for large-scale production systems.

```
```
