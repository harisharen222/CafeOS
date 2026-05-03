import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var pastedText = ""
    @State private var parseResults: [InventoryViewModel.CSVParseResult] = []
    @State private var hasPreviewedPaste = false
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var showToast = false
    @State private var fileParseResults: [InventoryViewModel.CSVParseResult] = []
    @State private var hasPreviewedFile = false

    private let csvTemplate = """
name,category,quantity,unit,minimumThreshold,costPerUnit
Item Name,Dairy,10,L,5,85
"""

    private var validPasteItems: [InventoryItem] {
        parseResults.compactMap { $0.item }
    }

    private var validFileItems: [InventoryItem] {
        fileParseResults.compactMap { $0.item }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab selector
                    Picker("", selection: $selectedTab) {
                        Text("Paste CSV").tag(0)
                        Text("Import File").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    if selectedTab == 0 {
                        pasteCsvTab
                    } else {
                        importFileTab
                    }
                }

                // Toast overlay
                if showToast {
                    VStack {
                        Spacer()
                        Text("Template copied to clipboard ✓")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.dashCard)
                            .cornerRadius(12)
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: showToast)
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: — Paste CSV Tab

    private var pasteCsvTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Header row with template button
                HStack {
                    Text("Paste your CSV data below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Download Template") {
                        UIPasteboard.general.string = csvTemplate
                        withAnimation { showToast = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { showToast = false }
                        }
                    }
                    .font(.caption.bold())
                    .foregroundColor(Color.dashCrimson)
                }
                .padding(.horizontal, 16)

                // Text editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $pastedText)
                        .scrollContentBackground(.hidden)
                        .background(Color.dashCard)
                        .foregroundColor(.white)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 160)
                        .cornerRadius(12)
                        .onChange(of: pastedText) { _, _ in
                            hasPreviewedPaste = false
                            parseResults = []
                        }

                    if pastedText.isEmpty {
                        Text("name,category,quantity,unit,minimumThreshold,costPerUnit\nOat Milk,Dairy,10,L,5,85\nEspresso Beans,Beverages,3,kg,2,1200")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.25))
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 16)

                // Preview button
                Button {
                    parseResults = inventoryVM.parseCSV(pastedText)
                    hasPreviewedPaste = true
                } label: {
                    Text("Preview")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(pastedText.isEmpty ? Color.dashCard : Color.dashMaroon)
                        .cornerRadius(10)
                }
                .disabled(pastedText.isEmpty)
                .padding(.horizontal, 16)

                // Preview results
                if hasPreviewedPaste {
                    previewList(parseResults)
                }

                // Import button
                if hasPreviewedPaste && !validPasteItems.isEmpty {
                    importButton(count: validPasteItems.count) {
                        Task {
                            isImporting = true
                            await inventoryVM.bulkImport(items: validPasteItems)
                            isImporting = false
                            dismiss()
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    // MARK: — Import File Tab

    private var importFileTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // File picker trigger
                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(Color.dashCrimson)
                        Text("Tap to select a CSV file")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Supports .csv files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.dashCard)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [UTType.commaSeparatedText],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                        if let text = try? String(contentsOf: url, encoding: .utf8) {
                            fileParseResults = inventoryVM.parseCSV(text)
                            hasPreviewedFile = true
                        }
                    case .failure:
                        break
                    }
                }

                // Preview results
                if hasPreviewedFile {
                    previewList(fileParseResults)
                }

                // Import button
                if hasPreviewedFile && !validFileItems.isEmpty {
                    importButton(count: validFileItems.count) {
                        Task {
                            isImporting = true
                            await inventoryVM.bulkImport(items: validFileItems)
                            isImporting = false
                            dismiss()
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    // MARK: — Shared sub-views

    @ViewBuilder
    private func previewList(_ results: [InventoryViewModel.CSVParseResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PREVIEW — \(results.filter { $0.isValid }.count) valid, \(results.filter { !$0.isValid }.count) invalid")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .kerning(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    HStack(spacing: 10) {
                        Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isValid ? .green : .red)
                            .font(.caption)

                        if let item = result.item {
                            Text(item.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(String(format: "%.0f", item.quantity)) \(item.unit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(result.rawName)
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                            Text(result.errorReason ?? "Invalid")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(result.isValid
                                ? Color.dashCard
                                : Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func importButton(count: Int, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if isImporting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text("Importing…")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                } else {
                    Text("Import \(count) Item\(count == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(count > 0 ? Color.dashCrimson : Color.dashCard)
            .cornerRadius(12)
        }
        .disabled(count == 0 || isImporting)
        .padding(.horizontal, 16)
    }
}
