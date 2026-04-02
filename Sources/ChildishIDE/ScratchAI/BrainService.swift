import Combine
import Foundation

/// On-device assistant: **phrase index** (instant, corpus-shaped) + **tiny MLP** with beam snippets.
/// Still pure Swift — no APIs, no network.
final class BrainService: ObservableObject {
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var lastTrainSteps: Int = 0
    @Published private(set) var status: String = "Scratch-AI ready. Train on your file for extra flavor!"
    @Published private(set) var isAutowriting = false

    private let events: EventBus
    private var model: MLPNextCharacter
    private var rng: SplitMix64
    private let phraseIndex = LocalPhraseIndex()
    private let modelLock = NSLock()

    /// Wider context so the net sees whole keywords, not four glyphs.
    private let contextLength = 12
    private let hiddenSize = 96

    init(events: EventBus, seed: UInt64 = 0xC0DE_F00D) {
        self.events = events
        rng = SplitMix64(seed: seed)
        let V = SymbolCodec.symbols.count
        model = MLPNextCharacter(vocabSize: V, contextLength: contextLength, hiddenSize: hiddenSize, rng: &rng)
        phraseIndex.ingest(lines: ToyCorpus.lines)
        warmStart(steps: 384, learningRate: 0.055)
    }

    /// Light training so the first suggestions are not random noise.
    private func warmStart(steps: Int, learningRate: Float) {
        let lines = ToyCorpus.lines
        guard !lines.isEmpty else { return }
        modelLock.lock()
        defer { modelLock.unlock() }
        for _ in 0 ..< steps {
            guard let line = lines.randomElement() else { continue }
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
        lastTrainSteps = steps
    }

    func refreshSuggestions(for text: String, maxItems: Int = 10) {
        modelLock.lock()
        let beam = model.beamSnippets(fromFullText: text, depth: 7, beamWidth: 14, charTopK: 4, limit: 5)
        let logits = model.forward(SymbolCodec.encodeContext(text, length: contextLength))
        let charIdx = model.topKIndices(logits: logits, k: 4)
        let charSnips = charIdx.map { String(SymbolCodec.character(forIndex: $0)) }
        modelLock.unlock()

        let phrases = phraseIndex.completions(following: text, limit: 6)

        var ordered: [String] = []
        var seen = Set<String>()
        func push(_ s: String) {
            let t = s
            guard !t.isEmpty, seen.insert(t).inserted else { return }
            ordered.append(t)
        }

        for p in phrases { push(p) }
        for b in beam { push(b) }
        for c in charSnips { push(c) }

        suggestions = Array(ordered.prefix(maxItems))
        events.emit(.suggestionsUpdated)
    }

    /// Train the neural net on bundled lines **plus** lines from the editor snapshot; refresh phrase index from editor.
    func train(steps: Int = 900, learningRate: Float = 0.05, editorSnapshot: String = "") {
        var pool = ToyCorpus.lines
        if !editorSnapshot.isEmpty {
            let extra = editorSnapshot.split(whereSeparator: { $0.isNewline }).map(String.init)
            pool.append(contentsOf: extra)
            phraseIndex.ingest(paragraph: editorSnapshot)
        }
        guard !pool.isEmpty else { return }

        modelLock.lock()
        defer { modelLock.unlock() }

        for _ in 0 ..< steps {
            guard let line = pool.randomElement(), !line.isEmpty else { continue }
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
        status = "Scratch-AI trained \(steps) more reps (total \(lastTrainSteps)). Still 100% offline."
        events.emit(.brainTrained(steps: steps))
    }

    // MARK: - “Do the coding for you” (offline)

    /// Full-file style drop from keyword-matched recipe + user wish echo.
    func generatedRecipeBlock(matching wish: String) -> String {
        let recipe = IntentRecipeRouter.bestMatch(for: wish) ?? CodeRecipes.all[0]
        let banner = "\n// MARK: — Scratch-AI built: \(recipe.title)\n// Wish: \(wish)\n"
        return banner + recipe.code + "\n"
    }

    func generatedRecipeBlock(recipe: CodeRecipe) -> String {
        "\n// MARK: — Scratch-AI built: \(recipe.title)\n" + recipe.code + "\n"
    }

    /// Greedy character loop — streams Swift-shaped text from the tiny on-device net.
    func neuralAutowrite(continuingFrom prefix: String, maxNewCharacters: Int) -> String {
        modelLock.lock()
        defer { modelLock.unlock() }

        var ctx = prefix
        var out = ""
        out.reserveCapacity(maxNewCharacters)
        var newlineRun = 0

        for _ in 0 ..< maxNewCharacters {
            let logits = model.forward(SymbolCodec.encodeContext(ctx, length: contextLength))
            guard let best = model.topKIndices(logits: logits, k: 1).first else { break }
            let ch = SymbolCodec.character(forIndex: best)
            out.append(ch)
            ctx.append(ch)

            if ch == "\n" {
                newlineRun += 1
                if newlineRun >= 4 { break }
            } else {
                newlineRun = 0
            }
        }

        return out
    }

    /// Runs `neuralAutowrite` off the main thread so UI stays responsive.
    func neuralAutowriteAsync(continuingFrom prefix: String, maxNewCharacters: Int, done: @escaping (String) -> Void) {
        isAutowriting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { done("") }
                return
            }
            let chunk = self.neuralAutowrite(continuingFrom: prefix, maxNewCharacters: maxNewCharacters)
            DispatchQueue.main.async {
                self.isAutowriting = false
                done(chunk)
            }
        }
    }
}
