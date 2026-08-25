set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes.
default:
    @just --list

# Initialize repository submodules.
setup:
    git submodule update --init --recursive

# Verify shared Kotlin/protocol prerequisites.
doctor:
    @command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }
    @command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }
    @command -v buf >/dev/null || { echo "error: buf is required" >&2; exit 1; }
    @./scripts/run-with-java-21.sh java -version >/dev/null 2>&1
    @echo "Native Kotlin/protocol prerequisites are ready."

# Verify Swift prerequisites on macOS.
doctor-swift: doctor
    @test "$(uname -s)" = "Darwin" || { echo "error: Swift builds require macOS" >&2; exit 1; }
    @command -v xcrun >/dev/null || { echo "error: Xcode command-line tools are required" >&2; exit 1; }
    @command -v rustup >/dev/null || { echo "error: rustup is required" >&2; exit 1; }
    @command -v protoc >/dev/null || { echo "error: protoc is required" >&2; exit 1; }
    @echo "Native Swift prerequisites are ready."

# Lint the client-to-client protocol.
protocol-lint:
    buf lint protocol

# Validate protocol conformance fixtures.
protocol-vectors:
    python3 protocol/conformance/validate.py

# Run every protocol check.
protocol-check: protocol-lint protocol-vectors

# Run Kotlin unit tests.
kotlin-unit:
    cd kotlin && ../scripts/run-with-java-21.sh ./gradlew :lib:test --no-daemon

# Generate Kotlin unit-test coverage reports.
kotlin-coverage:
    cd kotlin && ../scripts/run-with-java-21.sh ./gradlew :lib:koverHtmlReport :lib:koverXmlReport --no-daemon

# Enforce the Kotlin unit-test coverage floor.
kotlin-coverage-verify:
    cd kotlin && ../scripts/run-with-java-21.sh ./gradlew :lib:koverVerify --no-daemon

# Smoke-test the local Maven publication consumed by the app.
kotlin-publish-local:
    cd kotlin && ../scripts/run-with-java-21.sh ./gradlew :lib:publishToMavenLocal --no-daemon

# Run the full fast Kotlin CI gate.
kotlin-check: protocol-check kotlin-unit kotlin-coverage kotlin-coverage-verify kotlin-publish-local

# Run Kotlin server-dependent tests against an explicit local endpoint.
kotlin-integration api="http://localhost:3000":
    @curl -fsS "{{ api }}/openapi.yaml" >/dev/null || { echo "error: no Obscura server at {{ api }}" >&2; exit 1; }
    cd kotlin && OBSCURA_TEST_API="{{ api }}" ../scripts/run-with-java-21.sh ./gradlew :lib:integrationTest --no-daemon

# Fetch and build the pinned host libsignal FFI.
swift-bootstrap:
    ./swift/scripts/bootstrap-libsignal.sh host

# Prepare the local Swift package dependency.
swift-prepare: swift-bootstrap
    cd swift && ./dev.sh prepare

# Build the Swift package.
swift-build: swift-bootstrap
    cd swift && ./dev.sh build

# Run Swift unit tests.
swift-unit: swift-bootstrap
    cd swift && ./dev.sh test --filter UnitTests

# Run Swift server-dependent tests against an explicit local endpoint.
swift-integration api="http://localhost:3000": swift-bootstrap
    @curl -fsS "{{ api }}/openapi.yaml" >/dev/null || { echo "error: no Obscura server at {{ api }}" >&2; exit 1; }
    cd swift && OBSCURA_TEST_API="{{ api }}" ./dev.sh test --filter ScenarioTests

# Run every fast macOS gate.
check: kotlin-check swift-unit
