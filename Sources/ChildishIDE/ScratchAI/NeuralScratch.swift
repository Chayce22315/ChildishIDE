import Foundation

// MARK: - PRNG (deterministic option for reproducible micro-training)

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextFloatScaled() -> Float {
        let u = next()
        return (Float(u % 10_000) / 10_000 - 0.5) * 0.25
    }
}

// MARK: - Tiny MLP: predicts next symbol (scratch-built matmul + ReLU + softmax CE)

final class MLPNextCharacter {
    let vocabSize: Int
    let contextLength: Int
    let hiddenSize: Int
    let inputDim: Int

    var W1: [Float]
    var b1: [Float]
    var W2: [Float]
    var b2: [Float]

    init(vocabSize V: Int, contextLength C: Int, hiddenSize H: Int, rng: inout SplitMix64) {
        vocabSize = V
        contextLength = C
        hiddenSize = H
        inputDim = V * C
        W1 = (0 ..< H * inputDim).map { _ in rng.nextFloatScaled() }
        b1 = (0 ..< H).map { _ in rng.nextFloatScaled() }
        W2 = (0 ..< V * H).map { _ in rng.nextFloatScaled() }
        b2 = (0 ..< V).map { _ in rng.nextFloatScaled() }
    }

    /// Returns logits from input one-hot vector.
    func forward(_ x: [Float]) -> [Float] {
        precondition(x.count == inputDim)
        let H = hiddenSize
        let V = vocabSize
        let inD = inputDim

        var z1 = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            var s: Float = b1[i]
            let row = i * inD
            for j in 0 ..< inD {
                s += W1[row + j] * x[j]
            }
            z1[i] = s
        }

        var h = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            h[i] = max(0, z1[i])
        }

        var logits = [Float](repeating: 0, count: V)
        for k in 0 ..< V {
            var s: Float = b2[k]
            let row = k * H
            for i in 0 ..< H {
                s += W2[row + i] * h[i]
            }
            logits[k] = s
        }

        return logits
    }

    /// One SGD step on a single sample (softmax + cross-entropy).
    func trainStep(x: [Float], target: Int, learningRate lr: Float) {
        precondition(x.count == inputDim)
        let H = hiddenSize
        let V = vocabSize
        let inD = inputDim

        var z1 = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            var s: Float = b1[i]
            let row = i * inD
            for j in 0 ..< inD {
                s += W1[row + j] * x[j]
            }
            z1[i] = s
        }

        var h = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            h[i] = max(0, z1[i])
        }

        var logits = [Float](repeating: 0, count: V)
        for k in 0 ..< V {
            var s: Float = b2[k]
            let row = k * H
            for i in 0 ..< H {
                s += W2[row + i] * h[i]
            }
            logits[k] = s
        }

        var mx = logits[0]
        for k in 1 ..< V {
            mx = max(mx, logits[k])
        }
        var exps = [Float](repeating: 0, count: V)
        var sum: Float = 0
        for k in 0 ..< V {
            let v = exp(logits[k] - mx)
            exps[k] = v
            sum += v
        }
        var prob = [Float](repeating: 0, count: V)
        for k in 0 ..< V {
            prob[k] = exps[k] / sum
        }

        var dLogits = [Float](repeating: 0, count: V)
        for k in 0 ..< V {
            dLogits[k] = prob[k] - (k == target ? 1 : 0)
        }

        var dH = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            var s: Float = 0
            for k in 0 ..< V {
                s += dLogits[k] * W2[k * H + i]
            }
            dH[i] = s
        }

        var dZ1 = [Float](repeating: 0, count: H)
        for i in 0 ..< H {
            dZ1[i] = z1[i] > 0 ? dH[i] : 0
        }

        for k in 0 ..< V {
            let row = k * H
            for i in 0 ..< H {
                W2[row + i] -= lr * dLogits[k] * h[i]
            }
            b2[k] -= lr * dLogits[k]
        }

        for i in 0 ..< H {
            let row = i * inD
            for j in 0 ..< inD {
                W1[row + j] -= lr * dZ1[i] * x[j]
            }
            b1[i] -= lr * dZ1[i]
        }
    }

    func softmaxProbs(logits: [Float]) -> [Float] {
        let V = vocabSize
        var mx = logits[0]
        for k in 1 ..< V {
            mx = max(mx, logits[k])
        }
        var exps = [Float](repeating: 0, count: V)
        var sum: Float = 0
        for k in 0 ..< V {
            let v = exp(logits[k] - mx)
            exps[k] = v
            sum += v
        }
        return exps.map { $0 / sum }
    }

    func topKIndices(logits: [Float], k: Int) -> [Int] {
        let pairs = logits.enumerated().map { ($0.offset, $0.element) }
        let sorted = pairs.sorted { $0.1 > $1.1 }
        return sorted.prefix(k).map(\.0)
    }
}

// MARK: - Symbol codec

enum SymbolCodec {
    static let symbols: [Character] = {
        let base = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?:;()[]{}<>/\\\"'\n\t-_=+*&#@"
        var seen = Set<Character>()
        var out: [Character] = []
        for c in base {
            if seen.insert(c).inserted {
                out.append(c)
            }
        }
        return out
    }()

    static let indexByChar: [Character: Int] = {
        var m: [Character: Int] = [:]
        for (i, c) in symbols.enumerated() {
            m[c] = i
        }
        return m
    }()

    static func index(for char: Character) -> Int {
        indexByChar[char] ?? 0
    }

    static func character(forIndex i: Int) -> Character {
        guard i >= 0, i < symbols.count else { return symbols[0] }
        return symbols[i]
    }

    static func encodeContext(_ text: String, length: Int) -> [Float] {
        let V = symbols.count
        let pad = symbols[0]
        var chars: [Character] = Array(repeating: pad, count: length)
        let arr = Array(text)
        let take = min(length, arr.count)
        if take > 0 {
            let start = arr.count - take
            for i in 0 ..< take {
                chars[length - take + i] = arr[start + i]
            }
        }
        var x = [Float](repeating: 0, count: V * length)
        for t in 0 ..< length {
            let idx = index(for: chars[t])
            x[t * V + idx] = 1
        }
        return x
    }
}
