import Foundation

/// One writer for a device, including across account changes. A cancellation
/// never releases the writer until the transport actually returns.
@MainActor
public final class ReminderRegistrationCoordinator {
    public typealias Row = [String: JSONValue]
    public typealias Upload = @MainActor (Row) async -> Bool

    private struct Snapshot {
        var owner: String
        var generation: Int
        var values: Row
        var row: Row
        var upload: Upload
    }

    private var owner: String?
    private var generation = 0
    private var lastMillisecond: Int64 = 0
    private var pending: Snapshot?
    private var inFlight: Snapshot?
    private var acknowledged: Snapshot?
    private var timer: Task<Void, Never>?
    private var worker: Task<Void, Never>?
    private var paused = false

    public init() {}

    public func setOwner(_ owner: String?) {
        guard self.owner != owner else { return }
        self.owner = owner
        generation &+= 1
        timer?.cancel()
        timer = nil
        pending = nil
        acknowledged = nil
    }

    /// Capture before any await (especially authentication refresh). Retries
    /// retain this timestamp; they must not promote stale data to a new event.
    public func submit(owner: String, values: Row, delay: Duration = .seconds(10),
                       now: Date = Date(), upload: @escaping Upload) {
        setOwner(owner)
        var values = values
        values.removeValue(forKey: "updated_at")
        values.removeValue(forKey: "registration_updated_at")
        values["user_id"] = .string(owner)
        if pending?.values != values || pending?.generation != generation {
            if pending == nil, inFlight?.generation == generation, inFlight?.values == values {
                return
            }
            if inFlight == nil, acknowledged?.generation == generation, acknowledged?.values == values {
                pending = nil
                timer?.cancel()
                timer = nil
                return
            }
            lastMillisecond = max(lastMillisecond + 1, Int64((now.timeIntervalSince1970 * 1000).rounded(.down)))
            var row = values
            row["updated_at"] = .string(DayMath.timestamp(Date(timeIntervalSince1970: Double(lastMillisecond) / 1000)))
            pending = Snapshot(owner: owner, generation: generation, values: values, row: row, upload: upload)
        }
        timer?.cancel()
        timer = nil
        guard !paused else { return }
        // A running writer consumes the latest pending snapshot on completion.
        guard worker == nil else { return }
        if delay == .zero {
            startWorker()
        } else {
            timer = Task { [weak self] in
                do { try await Task.sleep(for: delay) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.timer = nil
                self.startWorker()
            }
        }
    }

    /// Wait for the entire coalesced batch, not merely the request that happened
    /// to be running when the app entered the background.
    public func flush() async {
        timer?.cancel()
        timer = nil
        startWorker()
        while let worker {
            await worker.value
        }
    }

    public func suspend() {
        paused = true
        timer?.cancel()
        timer = nil
        if pending == nil, let inFlight, inFlight.generation == generation { pending = inFlight }
        acknowledged = nil
        worker?.cancel()
    }

    /// The caller submits a fresh snapshot before flushing again.
    public func resume() { paused = false }

    private func startWorker() {
        guard !paused, worker == nil, pending != nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await self.drain()
            self.worker = nil
            // A foreground refresh may arrive while an expired request is
            // still unwinding. Do not strand that new snapshot.
            if Task.isCancelled, !self.paused { self.startWorker() }
        }
    }

    private func drain() async {
        while !paused, !Task.isCancelled, let next = pending {
            pending = nil
            guard next.generation == generation, next.owner == owner else { continue }
            if acknowledged?.generation == generation, acknowledged?.values == next.values { continue }
            // Even a failed response can mean the server applied this write.
            // The older acknowledgment can no longer suppress a later revert.
            acknowledged = nil
            inFlight = next
            let saved = await next.upload(next.row)
            inFlight = nil
            guard !Task.isCancelled else { return }
            guard next.generation == generation, next.owner == owner else { continue }
            if saved {
                acknowledged = next
            } else if pending == nil {
                pending = next
                return // retry on the next refresh/flush, never a tight loop
            }
        }
    }
}
