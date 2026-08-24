import Foundation
import GRDB

/// Bridges GRDB ValueObservation to Swift AsyncSequence.
/// Store observations use this internally to drive payload-free facade wake events.
///
/// Usage in SwiftUI:
/// ```swift
/// struct FriendListView: View {
///     let client: ObscuraClient
///     @State private var friends: [Friend] = []
///
///     var body: some View {
///         List(friends, id: \.userId) { friend in
///             Text(friend.username)
///         }
///         .task {
///             for await event in client.observeEvents() {
///                 if case .friendsChanged = event {
///                     friends = await client.getFriends()
///                 }
///             }
///         }
///     }
/// }
/// ```
public struct AsyncValueObservation<T: Sendable> {
    private let observation: ValueObservation<ValueReducers.Fetch<T>>
    private let db: DatabaseQueue

    init(observation: ValueObservation<ValueReducers.Fetch<T>>, in db: DatabaseQueue) {
        self.observation = observation
        self.db = db
    }

    /// AsyncSequence of observed values. Emits initial value immediately,
    /// then emits again on every database change affecting the query.
    public var values: AsyncStream<T> {
        AsyncStream { continuation in
            let cancellable = observation.start(in: db, onError: { error in
                // Log but don't crash — observation continues
                print("[ObscuraKit] observation error: \(error)")
            }, onChange: { value in
                continuation.yield(value)
            })

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
