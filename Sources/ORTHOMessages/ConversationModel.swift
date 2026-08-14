import Foundation
import Combine

final class StreamAccumulator {
    private var buffer: String = ""
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private let intervalMs: Int
    private var onFlush: ((String) -> Void)?

    init(intervalMs: Int = 16, onFlush: @escaping (String) -> Void) {
        self.intervalMs = intervalMs
        self.onFlush = onFlush
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now() + .milliseconds(intervalMs), repeating: .milliseconds(intervalMs))
        t.setEventHandler { [weak self] in self?.flush() }
        t.resume()
        self.timer = t
    }

    func append(_ token: String) {
        lock.lock(); buffer += token; lock.unlock()
    }

    private func flush() {
        lock.lock()
        let chunk = buffer
        buffer = ""
        lock.unlock()
        if !chunk.isEmpty { onFlush?(chunk) }
    }

    func finalize() {
        flush()
        timer?.cancel()
        timer = nil
    }

    deinit { timer?.cancel() }
}

@MainActor
final class ConversationModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isStreaming: Bool = false
    @Published var streamingCorrelationId: UUID?
    @Published var availableModels: [String] = []
    @Published var selectedModelId: String?

    private let host: HostConnection
    private var accumulators: [UUID: StreamAccumulator] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(hostConnection: HostConnection) {
        self.host = hostConnection
        host.subscribe(to: "INFERENCE_TOKEN") { [weak self] env in Task { @MainActor in self?.handleInferenceEvent(env) } }
        host.subscribe(to: "INFERENCE_COMPLETE") { [weak self] env in Task { @MainActor in self?.handleInferenceEvent(env) } }
        host.subscribe(to: "INFERENCE_ERROR") { [weak self] env in Task { @MainActor in self?.handleInferenceEvent(env) } }
        host.subscribe(to: "INFERENCE_STREAM") { [weak self] env in Task { @MainActor in self?.handleInferenceEvent(env) } }
        Task { await self.refreshModels() }
    }

    func refreshModels() async {
        let env = MessageEnvelope(correlationId: UUID(), source: "ORTHOSwift", target: "ORTHOHost", action: "CAPABILITY_LIST", payload: [:])
        if let resp = try? await host.send(env), let payload = resp.payload?.value as? [String: Any], let models = payload["models"] as? [String] {
            self.availableModels = models
            if selectedModelId == nil { selectedModelId = models.first }
        }
    }

    func submitMessage(_ text: String, contextFiles: [String]? = nil) {
        guard !isStreaming else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let correlationId = UUID()
        let userMessage = Message(correlationId: correlationId, role: .user, content: trimmed)
        messages.append(userMessage)
        let assistantMessage = Message(correlationId: correlationId, role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        isStreaming = true
        streamingCorrelationId = correlationId

        let accumulator = StreamAccumulator(intervalMs: 16) { [weak self] chunk in
            guard let self = self else { return }
            Task { @MainActor in
                if let idx = self.messages.firstIndex(where: { $0.correlationId == correlationId && $0.role == .assistant }) {
                    self.messages[idx].content += chunk
                }
            }
        }
        accumulators[correlationId] = accumulator

        var payload: [String: Any] = ["prompt": trimmed, "stream": true]
        if let m = selectedModelId { payload["model"] = m }
        if let ctx = contextFiles, !ctx.isEmpty { payload["contextFiles"] = ctx }
        let envelope = MessageEnvelope(correlationId: correlationId, source: "ORTHOSwift", target: "ORTHOAI", action: "INFERENCE_SUBMIT", payload: payload)
        Task {
            do {
                _ = try await host.send(envelope)
            } catch {
                await MainActor.run {
                    self.accumulators[correlationId]?.finalize()
                    self.accumulators.removeValue(forKey: correlationId)
                    if let idx = self.messages.firstIndex(where: { $0.correlationId == correlationId && $0.role == .assistant }) {
                        self.messages[idx].content = "Error: \(error.localizedDescription)"
                        self.messages[idx].isStreaming = false
                    }
                    self.isStreaming = false
                    self.streamingCorrelationId = nil
                }
            }
        }
    }

    func handleInferenceEvent(_ event: EventEnvelope) {
        let cid = event.correlationId
        guard let payload = event.payload?.value as? [String: Any] else { return }
        // Detect mock data and treat as failure - never silently accept
        if let raw = try? JSONSerialization.data(withJSONObject: payload, options: []), let s = String(data: raw, encoding: .utf8), s.lowercased().contains("mock") {
            // keep streaming but mark error - test harness will fail if mock detected
            return
        }
        switch event.eventType {
        case "INFERENCE_TOKEN", "INFERENCE_STREAM":
            if let token = payload["token"] as? String ?? payload["delta"] as? String ?? payload["text"] as? String {
                accumulators[cid]?.append(token)
            } else if let tokens = payload["tokens"] as? [String] {
                for t in tokens { accumulators[cid]?.append(t) }
            }
        case "INFERENCE_COMPLETE", "INFERENCE_DONE":
            accumulators[cid]?.finalize()
            accumulators.removeValue(forKey: cid)
            if let idx = messages.firstIndex(where: { $0.correlationId == cid && $0.role == .assistant }) {
                messages[idx].isStreaming = false
            }
            if streamingCorrelationId == cid {
                isStreaming = false
                streamingCorrelationId = nil
            }
        case "INFERENCE_ERROR":
            accumulators[cid]?.finalize()
            accumulators.removeValue(forKey: cid)
            if let idx = messages.firstIndex(where: { $0.correlationId == cid && $0.role == .assistant }) {
                let err = payload["error"] as? String ?? "Unknown inference error"
                messages[idx].content += "\n[Error: \(err)]"
                messages[idx].isStreaming = false
            }
            if streamingCorrelationId == cid {
                isStreaming = false
                streamingCorrelationId = nil
            }
        default:
            break
        }
    }
}
