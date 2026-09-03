# Documentation

Start with the shared contracts before changing either native implementation:

- [`NATIVE_CONTRACT.md`](NATIVE_CONTRACT.md) defines the cross-platform
  behavioral and security invariants.
- [`KIT_API.md`](KIT_API.md) defines the boundary between each native kit and
  the application.

## Contributor guides

- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) covers setup, checks, and the pull
  request workflow.
- [`../kotlin/README.md`](../kotlin/README.md) and
  [`../kotlin/CLAUDE.md`](../kotlin/CLAUDE.md) cover Kotlin development.
- [`../swift/README.md`](../swift/README.md) and
  [`../swift/CLAUDE.md`](../swift/CLAUDE.md) cover Swift development.
- [`../protocol/conformance/README.md`](../protocol/conformance/README.md)
  explains the shared wire conformance fixtures.

## Platform references

- Kotlin: [`authentication`](../kotlin/docs/AUTHENTICATION.md),
  [`friend codes`](../kotlin/docs/FRIEND_CODE.md), and
  [`implementation knowledge`](../kotlin/docs/knowledge/).
- Swift: [`client API`](../swift/docs/CLIENT_API.md),
  [`message flow`](../swift/docs/MESSAGE_FLOW.md),
  [`NSE prerequisites`](../swift/docs/NSE_PREREQUISITES.md), and
  [`pitfalls`](../swift/docs/PITFALLS.md).

## History

- [`HISTORY.md`](HISTORY.md) records completed contract and API migrations.
- [`HISTORY_IMPORT.md`](HISTORY_IMPORT.md) records the repository import
  mapping.
