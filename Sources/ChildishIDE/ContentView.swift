import SwiftUI
import UniformTypeIdentifiers

private let fileImportTypes: [UTType] = {
    var types: [UTType] = [.plainText, .utf8PlainText, .json, .text]
    if let swift = UTType(filenameExtension: "swift") {
        types.append(swift)
    }
    return types
}()

struct ContentView: View {
    @EnvironmentObject private var document: DocumentSession
    @EnvironmentObject private var brain: BrainService
    /// Kept in lockstep with `DocumentSession.defaultBufferText` so the first frame does not fight `TextEditor`.
    @State private var draftText: String = DocumentSession.defaultBufferText
    @State private var showImporter = false
    @State private var footerNote = "Ready to scribble code!"
    @State private var botWish = ""

    private let pastelPink = Color(red: 1, green: 0.62, blue: 0.8)
    private let pastelMint = Color(red: 0.5, green: 0.98, blue: 0.83)
    private let pastelSun = Color(red: 1, green: 0.9, blue: 0.4)
    private let ink = Color(red: 0.24, green: 0.16, blue: 0.27)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                editorBlock
                suggestionStrip
                botDoesTheCodingPanel
                trainRow
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.96, blue: 0.99),
                        Color(red: 0.94, green: 1, blue: 0.97),
                        Color(red: 1, green: 0.98, blue: 0.9),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if document.buffer.text != draftText {
                    draftText = document.buffer.text
                }
                brain.refreshSuggestions(for: draftText)
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: fileImportTypes,
                allowsMultipleSelection: false,
            ) { result in
                Task { @MainActor in
                    switch result {
                    case let .success(urls):
                        guard let url = urls.first else { return }
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if accessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                        do {
                            let got = try String(contentsOf: url, encoding: .utf8)
                            let name = url.lastPathComponent
                            document.setFromOpen(name: name, text: got)
                            draftText = got
                            footerNote = "Opened \(name) — wheee!"
                            brain.refreshSuggestions(for: draftText)
                        } catch {
                            footerNote = "Could not read that file."
                        }
                    case let .failure(err):
                        footerNote = "Import failed: \(err.localizedDescription)"
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Super Code Fort")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .shadow(color: .white, radius: 0, x: 2, y: 2)
            Spacer()
            Button {
                showImporter = true
            } label: {
                Label("Open stuff", systemImage: "folder.fill")
                    .font(.headline.weight(.heavy))
            }
            .buttonStyle(.borderedProminent)
            .tint(pastelSun)
            .foregroundStyle(ink)

            Button {
                footerNote = "Marked tidy!"
                document.markSaved(currentText: draftText)
            } label: {
                Label("Save", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline.weight(.heavy))
            }
            .buttonStyle(.borderedProminent)
            .tint(pastelMint)
            .foregroundStyle(ink)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [pastelPink, pastelMint.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
        )
        .overlay(
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .foregroundStyle(.white.opacity(0.9))
        )
    }

    private var editorBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Now editing: \(document.fileName)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(ink)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.92)))
                TextEditor(text: $draftText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .onChange(of: draftText) { _, newValue in
                        // Defer model + AI updates so we never re-enter `TextEditor` layout on the same turn (avoids AttributeGraph crashes).
                        DispatchQueue.main.async {
                            document.userEdited(newValue)
                            brain.refreshSuggestions(for: newValue)
                        }
                    }
            }
            .frame(minHeight: 280)
        }
        .padding()
    }

    private var suggestionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scratch-AI completions (phrases + neural beam)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(brain.suggestions.enumerated()), id: \.offset) { _, snippet in
                        Text(snippet)
                            .font(.system(size: snippet.count > 1 ? 15 : 22, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(pastelPink.opacity(0.65)))
                            .overlay(Capsule().stroke(ink, lineWidth: 2))
                            .onTapGesture {
                                draftText = CompletionMerge.apply(draft: draftText, snippet: snippet)
                            }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var botDoesTheCodingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scratch-AI writes whole files for you (offline)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(ink)

            TextField("Wish: swiftui list, network json, view model, animation…", text: $botWish)
                .textFieldStyle(.roundedBorder)
                .font(.body)

            HStack(spacing: 10) {
                Button {
                    let block = brain.generatedRecipeBlock(matching: botWish)
                    draftText += block
                    document.userEdited(draftText)
                    brain.refreshSuggestions(for: draftText)
                    footerNote = "Pasted a full recipe. Tweak names and ship!"
                } label: {
                    Label("Cook from wish", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.heavy))
                }
                .buttonStyle(.borderedProminent)
                .tint(pastelSun)
                .foregroundStyle(ink)
                .disabled(brain.isAutowriting)

                Button {
                    brain.neuralAutowriteAsync(continuingFrom: draftText, maxNewCharacters: 560) { chunk in
                        guard !chunk.isEmpty else {
                            footerNote = "Neural stream came back empty — try Train first."
                            return
                        }
                        draftText += "\n// MARK: — Neural stream —\n" + chunk + "\n"
                        document.userEdited(draftText)
                        brain.refreshSuggestions(for: draftText)
                        footerNote = "Neural bot typed a chunk at the end."
                    }
                } label: {
                    Label("Neural type-a-lot", systemImage: "keyboard")
                        .font(.subheadline.weight(.heavy))
                }
                .buttonStyle(.borderedProminent)
                .tint(pastelMint)
                .foregroundStyle(ink)
                .disabled(brain.isAutowriting)
            }

            if brain.isAutowriting {
                ProgressView("Tiny net is typing…")
                    .font(.footnote.weight(.semibold))
            }

            Text("Or tap a ready-made plate:")
                .font(.caption.weight(.bold))
                .foregroundStyle(ink.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CodeRecipes.all) { recipe in
                        Button {
                            draftText += brain.generatedRecipeBlock(recipe: recipe)
                            document.userEdited(draftText)
                            brain.refreshSuggestions(for: draftText)
                            footerNote = "Inserted: \(recipe.title)"
                        } label: {
                            Text(recipe.title)
                                .font(.caption.weight(.heavy))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(ink)
                        .disabled(brain.isAutowriting)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(ink.opacity(0.2), lineWidth: 2),
                ),
        )
        .padding(.horizontal)
    }

    private var trainRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                brain.train(steps: 900, editorSnapshot: draftText)
                brain.refreshSuggestions(for: draftText)
                footerNote = brain.status
            } label: {
                Text("Train on this file + corpus (still offline)")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(pastelPink)
            .foregroundStyle(ink)

            Text(footerNote)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink.opacity(0.85))
            Text(brain.status)
                .font(.footnote)
                .foregroundStyle(ink.opacity(0.7))
        }
        .padding()
    }
}

#Preview {
    PreviewShell()
}

private struct PreviewShell: View {
    @StateObject private var registry = ServiceRegistry()

    var body: some View {
        ContentView()
            .environmentObject(registry.document)
            .environmentObject(registry.brain)
    }
}
