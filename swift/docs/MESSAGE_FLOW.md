# Entry flow

## Sending

```text
obscura-pix resolves the audience and serializes opaque payload bytes
    ↓
ObscuraClient.send(to:modelKey:entryId:op:sentAt:payload:)
    ↓
fan out to every device of each caller-named user
    + own other devices
    - this sending device
    ↓
MessengerActor establishes device-UUID Signal sessions and encrypts
    ↓
POST /v1/messages
```

The kit does not write a local outgoing entry. The application already owns the
payload and writes its own copy through `client.entries`.

## Receiving

```text
gateway envelope
    ↓
validate sender_id + sender_device_id
    ↓
decrypt through the sender device UUID's Signal session
    ↓
classify the declared client.proto arm
    ├─ MODEL_SYNC / content references / unknown → inbox.put
    ├─ friend/device/session arms              → kit-owned handler
    ├─ MODEL_SIGNAL                            → in-memory signal store
    └─ declared unimplemented arms             → diagnose and drop
    ↓
emit optional wake-up event
    ↓
acknowledge the server envelope
```

For inboxed content, the durable write completes before the acknowledgement.
The app then performs:

```text
inbox.peek → authorize/merge in obscura-pix → entries.put → inbox.consume
```

`TEXT`, `SENT_SYNC`, and `SYNC_BLOB` are unimplemented compatibility arms. The
deleted native message model is not replaced by inbox rows the app cannot read.

Signal sessions are keyed by device UUID, never `registrationId`
(`NATIVE_CONTRACT.md` §0.10).
