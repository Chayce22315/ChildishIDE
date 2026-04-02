import Combine
import Foundation

/// On-device “AI” — tiny MLP trained from `ToyCorpus` only (no network I/O).
@MainActor
final class BrainService: ObservableObject {
    @Published private(set) var suggestions: [Character] = []
    @Published private(set) var lastTrainSteps: Int = 0
    @Published private(set) var status: String = "Brain is sleepy. Tap Train!"

    private let events: EventBus
    private var model: MLPNextCharacter
    private var rng: SplitMix64

    private let contextLength = 4
    private let hiddenSize = 40

    init(events: EventBus, seed: UInt64 = 0xC0DE_F00D) {
        self.events = events
        rng = SplitMix64(seed: seed)
        let V = SymbolCodec.symbols.count
        model = MLPNextCharacter(vocabSize: V, contextLength: contextLength, hiddenSize: hiddenSize, rng: &rng)
    }

    func refreshSuggestions(for text: String, topK: Int = 4) {
        let x = SymbolCodec.encodeContext(text, length: contextLength)
        let logits = model.forward(x)
        let idxs = model.topKIndices(logits: logits, k: topK)
        let chars = idxs.map { SymbolCodec.character(forIndex: $0) }
        suggestions = chars
        events.emit(.suggestionsUpdated)
    }

    func train(steps: Int = 400, learningRate: Float = 0.08) {
        let lines = ToyCorpus.lines
        guard !lines.isEmpty else { return }

        for _ in 0 ..< steps {
            let line = lines.randomElement()!
            let arr = Array(line)
            guard arr.count > contextLength else { continue }
            let pos = Int.random(in: contextLength ..< arr.count)
            let start = pos - contextLength
            let ctx = String(arr[start ..< pos])
            let nextChar = arr[pos]
            let x = SymbolCodec.encodeContext(ctx, length: contextLength)
            let target = SymbolCodec.index(for: nextChar)
            model.trainStep(x: x, target: target, learningRate: learningRate)
        }

        lastTrainSteps &+= steps
        status = "Brain did \(steps) practice reps! (total \(lastTrainSteps))"
        events.emit(.brainTrained(steps: steps))
    }
}
