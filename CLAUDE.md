# Obscura Native

Read [`docs/NATIVE_CONTRACT.md`](docs/NATIVE_CONTRACT.md) and
[`docs/KIT_API.md`](docs/KIT_API.md) before changing cross-platform behavior.
Platform-specific guidance remains in `kotlin/CLAUDE.md` and
`swift/CLAUDE.md`.

## Boundary

- `kotlin/` and `swift/` are native platform layers for one application:
  `obscura-pix`.
- They must agree on the wire contract in `proto/`, not on internal design.
- If a native layer reads a field, it must exist in
  `protocol/obscura/client/v1/client.proto`.
- Do not add app schemas, audience resolution, merge engines, expiry, query
  layers, or notification policy here.
- Persist inbox payloads before acknowledging their server envelopes.
- Address Signal sessions by device UUID, never `registrationId`.

## Shared protocol workflow

The root `proto/` submodule contains only the server/native transport contract.
Client content lives under `protocol/`. Do not add platform-local copies or
submodules. A schema-shape change requires regenerated Swift bindings and both
wire conformance suites.

## Commands

```bash
cd kotlin
JAVA_HOME=/path/to/jdk-21 ./gradlew :lib:test

cd ../swift
./dev.sh test --filter UnitTests
```

Swift builds require macOS. Server-dependent suites must preserve the
platform-specific pacing and cleanup rules.
