# Obscura Native

The native Android/JVM and Apple platform layers for `obscura-pix`.
They are single-consumer components, not general-purpose SDKs.

## Layout

| Path | Purpose |
|---|---|
| `kotlin/` | Kotlin/JVM kit used by the Android application bridge. |
| `swift/` | Swift package used by the iOS application bridge. |
| `proto/` | Shared `obscura-proto` contract and wire conformance vectors. |

The two implementations share the wire contract and security invariants. They
do not copy each other's architecture or promise broader feature parity.

## Contract boundary

Read [`proto/SPEC.md`](proto/SPEC.md) and
[`proto/KIT_API.md`](proto/KIT_API.md) before changing either platform.

The native layers own authentication, transport, Signal sessions,
friends/devices, durable inbox receipt, opaque entry storage, and
explicit-recipient sends. Model schemas, audience resolution, authorization,
merge, expiry, and notification policy belong in `obscura-pix`.

> If a native layer reads a field, it must be declared in `client.proto`.

## Clone

```bash
git clone --recurse-submodules <repository-url>
```

For an existing checkout:

```bash
git submodule update --init
```

## Build and test

```bash
# Kotlin: JDK 21
cd kotlin
./gradlew :lib:test

# Swift: macOS 13+ and Xcode 16+
cd ../swift
./dev.sh test --filter UnitTests
```

Kotlin integration tests and Swift scenario tests exercise a server. Follow
the platform guidance before running them.

## Protocol changes

Change canonical schemas and vectors in `obscura-proto`, update the root
`proto/` pin, regenerate Swift bindings when schema shape changes, and run both
platform conformance suites in the same change.

The original repositories and import mapping are recorded in
[`docs/HISTORY_IMPORT.md`](docs/HISTORY_IMPORT.md).
