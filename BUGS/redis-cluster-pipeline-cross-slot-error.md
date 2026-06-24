# Redis Cluster Pipeline Error

# Error: "All keys in the pipeline should belong to the same slots allocation group"

## Overview

When using Redis Cluster, you may encounter an error similar to:

```text
All keys in the pipeline should belong to the same slots allocation group
```

or

```text
CROSSSLOT Keys in request don't hash to the same slot
```

This error occurs when a Redis pipeline contains operations on multiple keys that belong to different hash slots.

Understanding why this happens requires understanding how Redis Cluster distributes data.

---

# Why This Happens

## Redis Cluster Uses Hash Slots

Redis Cluster divides all keys into:

```text
16384 hash slots
```

Each key is assigned a slot using:

```text
CRC16(key) % 16384
```

Example:

```text
user:1001  -> Slot 5234
user:2001  -> Slot 12987
```

Since the slots are different, the keys may reside on different Redis master nodes.

---

# Pipeline Execution in Redis Cluster

## How Pipeline Works

A pipeline batches multiple commands together and sends them to Redis in a single network round-trip.

Example:

```redis
SET user:1001 "John"
SET user:1002 "Alice"
SET user:1003 "Bob"
```

Instead of:

```text
Client -> Redis
Client -> Redis
Client -> Redis
```

Pipeline sends:

```text
Client -> [Batch of Commands] -> Redis
```

This improves performance by reducing network overhead.

---

# Problem in Redis Cluster

A Redis pipeline is typically executed against a single Redis node.

Consider:

```redis
SET user:1001 "John"
SET order:5001 "Order"
```

Suppose:

```text
user:1001  -> Slot 5234 -> Master A
order:5001 -> Slot 12890 -> Master B
```

Pipeline now contains commands targeting:

```text
Master A
Master B
```

Redis cannot execute this pipeline as a single request because:

* Pipeline connection is established to one node.
* Commands belong to different nodes.
* Redis Cluster does not automatically split and redistribute pipeline commands.

Result:

```text
All keys in the pipeline should belong to the same slots allocation group
```

---

# Visual Representation

## Valid Pipeline

```text
Pipeline
   |
   +--> user:{1001}:name
   +--> user:{1001}:email
   +--> user:{1001}:address

All keys
     |
     v
 Same Slot
     |
     v
 Same Redis Node
```

Pipeline succeeds.

---

## Invalid Pipeline

```text
Pipeline
   |
   +--> user:1001
   +--> order:5001

user:1001  -> Slot 5234
order:5001 -> Slot 12890
```

```text
Slot 5234  -> Master A
Slot 12890 -> Master B
```

Pipeline fails.

---

# Common Scenarios That Trigger This Error

## Scenario 1: Multiple SET Commands

```redis
SET user:1 "John"
SET user:2 "Alice"
```

Even though both use the same command:

```text
SET
```

the keys are different.

Different keys usually generate different slots.

---

## Scenario 2: Batch Cache Updates

```redis
SET product:100 value1
SET user:200 value2
SET order:300 value3
```

Keys likely belong to different slots.

Pipeline fails.

---

## Scenario 3: Multi-Key Operations

```redis
MGET user:1 user:2
```

If keys belong to different slots:

```text
CROSSSLOT Keys in request don't hash to the same slot
```

---

## Scenario 4: Transactions

```redis
MULTI
SET user:1 value1
SET order:1 value2
EXEC
```

Different slots cause transaction failure.

---

# Root Cause Analysis

The actual root cause is:

```text
One pipeline
       |
       v
Multiple hash slots
       |
       v
Multiple Redis nodes
       |
       v
Routing ambiguity
```

Redis Cluster requires all keys participating in a pipeline, transaction, or multi-key operation to belong to the same slot.

---

# Resolution Options

## Solution 1: Use Redis Hash Tags (Recommended)

### What Are Hash Tags?

Redis allows defining a custom portion of the key to be used for hashing.

Syntax:

```text
{tag}
```

Only the content inside braces is hashed.

---

### Example

Without hash tags:

```redis
user:1001:name
user:1001:email
```

May produce different slots.

---

With hash tags:

```redis
user:{1001}:name
user:{1001}:email
```

Redis hashes only:

```text
1001
```

Both keys now belong to the same slot.

---

### Pipeline Example

```redis
SET user:{1001}:name "John"
SET user:{1001}:email "john@test.com"
SET user:{1001}:phone "123456"
```

All keys:

```text
Same Hash Tag
      |
      v
Same Slot
      |
      v
Same Node
```

Pipeline succeeds.

---

# Solution 2: Group Commands By Slot

Instead of one large pipeline:

```redis
SET user:1 value1
SET order:1 value2
SET product:1 value3
```

Create separate pipelines.

Example:

```text
Pipeline A -> Slot Group A
Pipeline B -> Slot Group B
Pipeline C -> Slot Group C
```

Many Redis clients can perform slot-aware batching.

---

# Solution 3: Use Separate Pipelines

Instead of:

```java
pipeline.set("user:1", value1);
pipeline.set("order:1", value2);
pipeline.sync();
```

Use:

```java
pipeline1.set("user:1", value1);
pipeline1.sync();

pipeline2.set("order:1", value2);
pipeline2.sync();
```

Works but reduces batching benefits.

---

# Solution 4: Let Cluster-Aware Client Handle Routing

Some modern clients support cluster-aware pipelining.

Examples:

* Lettuce
* Jedis Cluster
* Redisson

These clients may:

```text
Group commands by slot
Create internal pipelines
Send to appropriate nodes
Merge responses
```

However:

* Support differs by client.
* Not all pipeline APIs are cluster-aware.
* Always verify implementation details.

---

# Solution 5: Redesign Key Structure

If keys are frequently used together:

Instead of:

```text
user:1001:name
user:1001:email
user:1001:phone
```

Use:

```text
user:{1001}:name
user:{1001}:email
user:{1001}:phone
```

This is the most common production solution.

---

# Example: Before and After

## Before (Fails)

```redis
SET user:1 "John"
SET user:2 "Alice"
```

Possible slots:

```text
user:1 -> Slot 4500
user:2 -> Slot 9000
```

Different slots.

Pipeline may fail.

---

## After (Succeeds)

```redis
SET user:{group1}:1 "John"
SET user:{group1}:2 "Alice"
```

Hashed value:

```text
group1
```

Both keys:

```text
Same Slot
```

Pipeline succeeds.

---

# Best Practices

## Use Hash Tags for Related Data

Good:

```text
cart:{user123}
cart:{user123}:items
cart:{user123}:discount
```

Bad:

```text
cart:user123
cart:user123:items
cart:user123:discount
```

---

## Design Keys Early

Changing key structure after production deployment is expensive.

Plan hash tag strategy during system design.

---

## Keep Related Data Together

Group:

* User profile data
* Shopping cart data
* Session data
* Transaction data

into the same slot when multi-key operations are required.

---

## Avoid Giant Hash Tag Groups

Bad:

```text
everything:{global}
```

This forces all keys into one slot.

Consequences:

* Hotspot creation
* Uneven load distribution
* Reduced cluster scalability

---

# Frequently Asked Questions

## Does Redis Pipeline Require Same Slot?

In Redis Cluster, generally yes.

All commands within a pipeline must target the same node unless the client explicitly supports cluster-aware pipelining.

---

## Does Using the Same Command Matter?

No.

The command type is irrelevant.

Example:

```redis
SET user:1 value1
SET user:2 value2
```

Both use SET.

The issue is that:

```text
user:1
user:2
```

may hash to different slots.

---

## Does Sentinel Have This Problem?

No.

Sentinel mode has only one master node.

All keys reside on the same logical Redis instance.

---

## Does Standalone Redis Have This Problem?

No.

There is only one Redis server.

No slot-based sharding exists.

---

# Summary

The error:

```text
All keys in the pipeline should belong to the same slots allocation group
```

occurs because Redis Cluster distributes keys across multiple hash slots and multiple nodes.

A pipeline can only be executed against a single node. If the pipeline contains keys belonging to different hash slots, Redis cannot route the commands as a single operation.

Most common fix:

```text
Use Redis Hash Tags
```

Example:

```text
user:{123}:name
user:{123}:email
user:{123}:settings
```

This guarantees that all related keys are stored in the same hash slot and can participate in pipelines, transactions, Lua scripts, and multi-key operations.
