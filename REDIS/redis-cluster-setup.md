# Redis Cluster - Beginner Friendly Guide

# Redis Cluster Documentation

## Table of Contents

1. Introduction
2. What is Redis?
3. What is Redis Cluster?
4. Why Use Redis Cluster?
5. Cluster Architecture
6. Prerequisites
7. Folder Structure
8. Running the Cluster
9. What the Script Does
10. Verifying the Cluster
11. Connecting to the Cluster
12. Basic Redis Commands
13. Stopping the Cluster
14. Troubleshooting
15. Frequently Asked Questions

---

# 1. Introduction

This document explains how to start and use a **Redis Cluster** using the provided Windows batch script.

It is intended for beginners who are new to Redis and Redis Clustering.

---

# 2. What is Redis?

Redis (**Remote Dictionary Server**) is an in-memory data store used as:

- Cache
- Database
- Message Broker
- Session Store
- Distributed Lock Manager

Redis stores data in memory, making it extremely fast.

Example:

```
User Login
      │
      ▼
Application
      │
      ▼
Redis
```

Instead of querying a database every time, applications can quickly retrieve data from Redis.

---

# 3. What is Redis Cluster?

A Redis Cluster is a group of Redis servers working together as one logical Redis database.

Instead of storing all data on one server, Redis distributes data across multiple servers.

Example:

```
                Redis Cluster

          +---------------+
          |   Client App  |
          +-------+-------+
                  |
      ------------------------------
      |            |               |
      ▼            ▼               ▼
 Node 7000     Node 7001      Node 7002
      ▲            ▲               ▲
      |            |               |
 Replica        Replica        Replica
 7003           7004           7005
```

---

# 4. Why Use Redis Cluster?

Without clustering:

```
Application
      │
      ▼
 Single Redis Server
```

Problems:

- Single point of failure
- Memory limit
- No scaling

---

With clustering:

```
Application
      │
      ▼
Redis Cluster

7000
7001
7002
7003
7004
7005
```

Benefits:

- High Availability
- Automatic Failover
- Horizontal Scaling
- Better Performance
- Data Sharding

---

## High Availability

If one master server crashes:

```
Master 7000
      X

Replica 7003

↓

7003 becomes the new master automatically.
```

Your application continues working.

---

## Data Sharding

Redis Cluster splits data into **16384 slots**.

Example:

```
Slots 0 - 5460
        │
        ▼
     Node 7000

Slots 5461 - 10922
        │
        ▼
     Node 7001

Slots 10923 - 16383
        │
        ▼
     Node 7002
```

When you save:

```
SET user:100 "John"
```

Redis hashes the key and automatically decides which node stores it.

You don't need to choose the node manually.

---

# 5. Cluster Architecture

Your script creates:

| Port | Role |
|-------|------|
|7000|Master|
|7001|Master|
|7002|Master|
|7003|Replica|
|7004|Replica|
|7005|Replica|

Total Nodes:

- 3 Masters
- 3 Replicas

---

Example:

```
Master 7000
     │
 Replica 7003

Master 7001
     │
 Replica 7004

Master 7002
     │
 Replica 7005
```

---

# 6. Prerequisites

Before running the script:

You should have:

- Redis installed
- `redis-server.exe`
- `redis-cli.exe`

Example:

```
Redis-x64-5.0.14.1/

    redis-server.exe
    redis-cli.exe
```

Update the script:

```bat
set REDIS_PATH=C:\Users\YourName\Documents\Redis-x64-5.0.14.1
```

to match your installation path.

---

# 7. Folder Structure

After running the script:

```
Redis-x64-5.0.14.1/

│
├──7000
│   ├──appendonly.aof
│   └──nodes.conf
│
├──7001
├──7002
├──7003
├──7004
└──7005
```

Each folder stores that node's:

- data
- configuration
- append-only file

---

# 8. Running the Cluster

Simply double-click:

```
start-redis-cluster.bat
```

or run:

```
start-redis-cluster.bat
```

from Command Prompt.

The script will:

- Create node folders
- Start 6 Redis servers
- Wait until every node is ready
- Check if the cluster already exists
- Create the cluster if needed
- Display cluster information

---

# 9. What the Script Does

## Step 1

Checks Redis executables exist.

```
redis-server.exe
redis-cli.exe
```

---

## Step 2

Creates folders:

```
7000
7001
7002
7003
7004
7005
```

---

## Step 3

Starts six Redis instances.

Each instance runs on a different port.

```
7000

7001

7002

7003

7004

7005
```

---

## Step 4

Waits until every node replies:

```
PING

PONG
```

---

## Step 5

Checks whether a cluster already exists.

```
cluster info
```

If:

```
cluster_state:ok
```

the script skips cluster creation.

---

## Step 6

Creates the cluster.

Equivalent command:

```bash
redis-cli --cluster create \
127.0.0.1:7000 \
127.0.0.1:7001 \
127.0.0.1:7002 \
127.0.0.1:7003 \
127.0.0.1:7004 \
127.0.0.1:7005 \
--cluster-replicas 1
```

This means:

- 3 masters
- 3 replicas

---

## Step 7

Displays:

```
cluster info

cluster nodes

cluster slots
```

---

# 10. Verifying the Cluster

Open Command Prompt.

Run:

```bash
redis-cli -c -p 7000
```

The `-c` option enables cluster mode.

Check:

```
127.0.0.1:7000> cluster info
```

Expected:

```
cluster_state:ok
```

---

View nodes:

```
cluster nodes
```

Example:

```
7000 master
7001 master
7002 master
7003 slave
7004 slave
7005 slave
```

---

View slot allocation:

```
cluster slots
```

---

# 11. Connecting to the Cluster

Always use cluster mode.

```
redis-cli -c -p 7000
```

or

```
redis-cli -c -p 7001
```

or any node.

Redis automatically redirects requests to the correct node.

---

# 12. Basic Redis Commands

Store a value:

```
SET name Alice
```

Retrieve:

```
GET name
```

Delete:

```
DEL name
```

Increment:

```
INCR counter
```

List keys (development only):

```
KEYS *
```

Check the node handling a key:

```
CLUSTER KEYSLOT name
```

---

## Example Session

```
redis-cli -c -p 7000

SET user:1 John

OK

GET user:1

John
```

Redis automatically routes the request to the correct node.

---

# 13. Stopping the Cluster

Each Redis server is running in its own Command Prompt window.

To stop:

Press:

```
Ctrl + C
```

in every Redis node window.

or simply close all Redis windows.

---

# 14. Troubleshooting

## Cluster creation fails

Delete:

```
7000
7001
7002
7003
7004
7005
```

Run the script again.

---

## Port already in use

Another Redis server may already be running.

Check:

```
7000

7001

7002
```

Stop existing Redis instances.

---

## Cluster state is "fail"

Run:

```
cluster info
```

Check whether all six nodes are running.

---

## Cannot connect

Verify:

```
redis-cli -p 7000 ping
```

Expected:

```
PONG
```

---

## Node already belongs to another cluster

Delete:

```
nodes.conf
```

inside each node directory.

Restart the script.

---

# 15. Frequently Asked Questions

## Why six nodes?

Redis recommends:

- 3 masters
- 3 replicas

This provides fault tolerance.

---

## Can I use only three nodes?

Yes.

However, there will be no replicas.

If a master fails, data may become unavailable.

---

## Why use replicas?

Replicas provide backup copies of master nodes.

If a master crashes, Redis automatically promotes its replica to become the new master.

---

## Do I need to choose which node stores my data?

No.

Redis Cluster automatically determines the correct node using hash slots.

---

## Can my application connect to only one node?

Yes.

Connect using:

```
redis-cli -c -p 7000
```

Cluster-aware clients automatically redirect requests to the appropriate node.

---

# Summary

Your script automates the complete setup of a local Redis Cluster by:

- Starting six Redis servers
- Creating individual data directories
- Waiting for all nodes to become available
- Creating a Redis Cluster (if one doesn't already exist)
- Configuring three master nodes and three replica nodes
- Displaying cluster information for verification

This setup is ideal for local development, learning Redis Cluster concepts, and testing applications that require a distributed Redis environment.