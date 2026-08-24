---
name: Generated Kotlin naming gotchas
description: SQLDelight column 'data' becomes 'data_', and protobuf/Okio ByteString types are distinct.
type: feedback
---

**SQLDelight column escaping:**
- Column named `data` becomes `data_` in generated Kotlin (reserved word)
- Use `data_` in all insert/query calls: `insertEntry(data_ = jsonString, ...)`

**OkioByteString vs protobuf ByteString:**
- OkHttp WebSocket uses `okio.ByteString`
- Protobuf uses `com.google.protobuf.ByteString`
- Import carefully. For WebSocket send: `OkioByteString.of(*frame.toByteArray())`
- For proto fields: `ByteString.copyFrom(bytes)`

**How to apply:** When writing protobuf transport code or SQLDelight queries, watch for these.
The compiler errors are confusing if you don't know the generated types and escaping rules.
