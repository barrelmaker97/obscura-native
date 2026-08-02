# Repository history import

`obscura-native` combines the complete `main` histories of the former platform
repositories. Each history was rewritten into its permanent subdirectory with
`git filter-repo --to-subdirectory-filter` and then merged without squashing.

| Platform | Source repository | Imported source `main` | Filtered head |
|---|---|---|---|
| Kotlin | `rhelsing/ObscuraKit-Kotlin` | `235615666ccf06467d19428d53e20b6d6ae01a38` | `1b0422b41aefd6b8dc3c84b027e503301a511970` |
| Swift | `rhelsing/ObscuraKit-swift` | `37ce524ca23666661e8d00097874eac5655670e4` | `ade52c1095d2d9ee09c2578fa83f1443ec381859` |

Authors, timestamps, and commit messages are preserved. Commit hashes changed
because every historical file path gained a platform prefix. The source
repositories remain the authority for old pull-request and commit URLs.
