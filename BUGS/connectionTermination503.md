# Understanding Envoy/Istio `503 UC` Errors (`upstream_reset_before_response_started{connection_termination}`)

## Overview

This document explains a common issue observed in Kubernetes environments using Istio/Envoy where requests intermittently fail with errors similar to:

```text
503 UC
upstream_reset_before_response_started{connection_termination}
```

The goal of this document is to explain:

* What the error means
* Why it happens
* How it relates to Node.js applications
* How to investigate it
* Potential resolutions

---

# Architecture

A typical request flow looks like:

```text
Client
   │
   ▼
Envoy / Istio Proxy
   │
   ▼
Node.js Application
```

Envoy maintains a pool of reusable TCP/HTTP connections to the application in order to improve performance.

Instead of opening a new connection for every request, Envoy tries to reuse existing connections whenever possible.

---

# What Does `503 UC` Mean?

Example log:

```text
503 UC
upstream_reset_before_response_started{connection_termination}
```

Where:

* `503` = Service unavailable
* `UC` = Upstream Connection Termination

This means:

> Envoy attempted to send a request to the upstream application, but the upstream connection was terminated before Envoy received a valid response.

Important:

`UC` does not automatically mean Envoy is at fault.

It only means Envoy observed that the upstream connection disappeared.

---

# Common Causes

## Cause 1: Application Closed the Connection

The Node.js application may close an idle keep-alive connection.

Example:

```text
Envoy connection pool
        │
        ▼
Connection idle for some time
        │
        ▼
Node.js closes connection
        │
        ▼
Envoy attempts to reuse it
        │
        ▼
Connection already closed
        │
        ▼
503 UC
```

This is one of the most common causes.

---

## Cause 2: Pod Restart or Termination

Example:

```text
Pod receives SIGTERM
        │
        ▼
Application starts shutdown
        │
        ▼
Connections are closed
        │
        ▼
Envoy sees connection termination
        │
        ▼
503 UC
```

This may happen during:

* Deployments
* Rollouts
* Node maintenance
* Scaling events

---

## Cause 3: Network or Load Balancer Timeout

A network device may close idle connections:

```text
Envoy
  │
  ▼
Load Balancer / Firewall
  │
  ▼
Node.js
```

If the intermediate device closes an idle connection before Envoy notices, Envoy may attempt to reuse a stale connection.

---

# Initial Investigation

During troubleshooting we observed:

```text
Health check failures
HTTP header timeout
```

Example:

```text
Readiness probe timeout
```

Initially this appeared to be related to the `503 UC` errors.

However:

* Probe timeout was increased
* Health check failures disappeared
* `503 UC` errors continued

This suggests that the health check issue and the connection termination issue may be separate problems.

---

# Most Likely Root Cause

A likely explanation is a connection lifecycle mismatch between Envoy and the Node.js application.

## What is a Connection Lifecycle Mismatch?

Envoy and Node.js both maintain their own timeout settings.

Example:

```text
Node.js closes idle connection after X seconds
Envoy attempts to reuse connection after X+N seconds
```

Result:

```text
Envoy reuses connection
        │
        ▼
Connection already closed by Node.js
        │
        ▼
503 UC
```

This behavior has been discussed in community issues involving Envoy and Istio.

---

# How Keep-Alive Works

Without keep-alive:

```text
Request
Connect
Response
Disconnect
```

With keep-alive:

```text
Connect
Request 1
Response 1

Request 2
Response 2

Request 3
Response 3
```

The same connection is reused multiple times.

This improves performance but requires both sides to agree on how long connections remain valid.

---

# Node.js Settings to Verify

The following values should be reviewed:

```javascript
console.log(server.keepAliveTimeout);
console.log(server.headersTimeout);
console.log(server.requestTimeout);
```

Important settings:

| Setting          | Description                              |
| ---------------- | ---------------------------------------- |
| keepAliveTimeout | How long an idle connection remains open |
| headersTimeout   | Maximum time to receive HTTP headers     |
| requestTimeout   | Maximum request processing time          |

---

# Istio / Envoy Settings to Verify

Review any configured:

* DestinationRule
* ConnectionPoolSettings
* Idle timeouts
* Max requests per connection
* TCP keep-alive settings

Example:

```yaml
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100
    http:
      idleTimeout: 30s
```

The exact values depend on the application workload.

---

# How to Verify Whether This Is a Keep-Alive Issue

## Indicator 1

A request fails with:

```text
503 UC
```

but an immediate retry succeeds.

---

## Indicator 2

Errors occur after periods of low traffic or inactivity.

---

## Indicator 3

No pod restarts are observed.

```bash
kubectl describe pod <pod>
```

No:

```text
OOMKilled
CrashLoopBackOff
Restarted
```

---

## Indicator 4

Health checks are healthy but `503 UC` continues.

This was observed in our environment after increasing probe timeout values.

---

# Recommended Actions

## 1. Review Node.js Timeout Settings

Verify:

```javascript
server.keepAliveTimeout
server.headersTimeout
server.requestTimeout
```

---

## 2. Review Istio DestinationRule Configuration

Verify:

* Idle timeout
* Connection reuse settings
* Connection pool settings

---

## 3. Align Connection Lifetimes

Ensure Envoy and Node.js use compatible timeout values.

Goal:

```text
Envoy should not attempt to reuse a connection that the application has already closed.
```

---

## 4. Monitor Application Performance

Investigate:

* CPU throttling
* Event-loop delays
* Memory pressure
* Long GC pauses
* Slow downstream dependencies

Even if they are not the direct cause, they can contribute to connection instability.

---

# Additional Resolution: Configure VirtualService Timeouts

In Kubernetes environments using Istio, another mitigation that has been observed to reduce or eliminate intermittent `503 UC` errors is configuring an explicit timeout in the VirtualService for the affected service.

## Why This Can Help

By default, request handling may rely on inherited Envoy/Istio timeout behavior.

In some scenarios:

```text
Client
   │
   ▼
Envoy Sidecar
   │
   ▼
Upstream Service
```

a request may remain in-flight longer than expected due to:

* Network latency
* Connection reuse behavior
* Backend processing delays
* Transient connection issues

When timeout behavior is not explicitly defined, Envoy may terminate or reset upstream requests in a way that surfaces as:

```text
503 UC
upstream_reset_before_response_started{connection_termination}
```

Defining a service-specific timeout provides more predictable request lifecycle management.

---

## Example VirtualService Configuration

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - timeout: 60s
      route:
        - destination:
            host: my-service
```

Example:

```text
Request Timeout = 60 seconds
```

This instructs Envoy to allow requests to remain active for up to 60 seconds before timing out.

---

## How to Choose a Timeout

The timeout should be based on the application's expected response times.

Example:

| Service Type            | Suggested Timeout |
| ----------------------- | ----------------- |
| Low latency APIs        | 5s - 15s          |
| Standard business APIs  | 15s - 60s         |
| Long-running operations | 60s+              |

Avoid setting extremely large values unless required.

---

## Verification

After applying the VirtualService timeout:

Monitor:

```text
503 UC
upstream_reset_before_response_started{connection_termination}
```

along with:

* Request latency
* Upstream response times
* Retry counts
* Envoy access logs
* Application logs

If error frequency decreases significantly after introducing the timeout, the issue may be related to request lifecycle management within the service mesh.

---

## Important Note

A VirtualService timeout should be considered a mitigation or configuration tuning option rather than proof of root cause.

If `503 UC` errors continue to occur, additional investigation should still focus on:

* Node.js keep-alive settings
* Envoy connection pools
* DestinationRule configuration
* Pod termination handling
* Connection idle timeout mismatches
* Network infrastructure timeouts

Timeout configuration is most effective when used together with proper connection lifecycle alignment between Envoy and the upstream application.


# Conclusion

The observed `503 UC` errors indicate that Envoy is losing the upstream connection before receiving a response.

Although readiness probe timeouts were initially present, increasing the probe timeout resolved those failures while the `503 UC` errors continued.

The current leading hypothesis is a mismatch between Envoy connection reuse behavior and the Node.js application's connection lifecycle, causing Envoy to occasionally attempt reuse of connections that have already been closed by the backend.

Further investigation should focus on:

1. Node.js keep-alive configuration
2. Istio/Envoy connection pool settings
3. Connection idle timeout alignment
4. Application performance and resource utilization

These checks will help determine whether the issue is caused by stale connection reuse, application-side connection closure, or another upstream networking condition.

## References

- Envoy issue #14981: `503 UC` / `upstream_reset_before_response_started{connection_termination}`
  - https://github.com/envoyproxy/envoy/issues/14981

- Istio issue #18043: Connection termination and stale upstream connection reuse discussion
  - https://github.com/istio/istio/issues/18043