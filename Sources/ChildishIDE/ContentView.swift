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
    @State private var draftText: String = ""
    @State private var showImporter = false
    @State private var footerNote = "Ready to scribble code!"

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
            .task {
                draftText = document.buffer.text
                brain.refreshSuggestions(for: draftText)
            }
            .onChange(of: document.buffer) { _, newBuffer in
                if newBuffer.text != draftText {
                    draftText = newBuffer.text
                }
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
                        document.userEdited(newValue)
                        brain.refreshSuggestions(for: newValue)
                    }
            }
            .frame(minHeight: 280)
        }
        .padding()
    }

    private var suggestionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scratch-AI guesses next character")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(brain.suggestions.enumerated()), id: \.offset) { _, ch in
                        Text(String(ch))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(pastelPink.opacity(0.65)))
                            .overlay(Circle().stroke(ink, lineWidth: 2))
                            .onTapGesture {
                                draftText.append(ch)
                            }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var trainRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                brain.train(steps: 300)
                brain.refreshSuggestions(for: draftText)
                footerNote = brain.status
            } label: {
                Text("Train the brain (on-device, no internet)")
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
