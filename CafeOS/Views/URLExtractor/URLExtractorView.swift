import SwiftUI

struct URLExtractorView: View {
    @StateObject private var viewModel = URLExtractorViewModel()
    // NOTE: URLExtractorViewModel is created locally with @StateObject because this view
    // is self-contained and not shared across tabs. This is the one intentional exception
    // to the environmentObject pattern — it owns its own ephemeral state.

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Explanation card
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Job URL Extractor", systemImage: "link")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Paste a job listing URL from LinkedIn, Indeed, Naukri, or any site. The app fetches and extracts the job description — even when direct scraping is blocked.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.dashCard)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // URL input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job Listing URL")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        HStack {
                            TextField("https://www.linkedin.com/jobs/...", text: $viewModel.urlText)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.dashCard)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                                )

                            if !viewModel.urlText.isEmpty {
                                Button {
                                    viewModel.clear()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Error banner
                    if viewModel.showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(viewModel.errorMessage ?? "")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Extract button
                    Button {
                        Task { await viewModel.extract() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                            }
                            Text(viewModel.isLoading ? "Extracting..." : "Extract Job Description")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.urlText.isEmpty
                                    ? Color.gray.opacity(0.3)
                                    : Color.dashCrimson)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.urlText.isEmpty || viewModel.isLoading)
                    .padding(.horizontal)

                    // Result
                    if viewModel.hasResult {
                        VStack(alignment: .leading, spacing: 12) {

                            // Content header row
                            HStack {
                                Text("Extracted Content")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Copy") {
                                    UIPasteboard.general.string = viewModel.extractedContent
                                }
                                .font(.subheadline)
                                .foregroundColor(Color.dashCrimson)
                            }
                            .padding(.horizontal)

                            // Extracted text — Fix 2: caption font with line spacing
                            Text(viewModel.extractedContent)
                                .font(.caption)
                                .lineSpacing(4)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.dashCard)
                                .cornerRadius(10)
                                .textSelection(.enabled)
                                .padding(.horizontal)

                            // Export as PDF button
                            Button {
                                viewModel.generatePDF()
                            } label: {
                                if viewModel.isGeneratingPDF {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Generating PDF…")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label("Export as PDF", systemImage: "arrow.down.doc.fill")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .background(viewModel.isGeneratingPDF
                                        ? Color.dashCard
                                        : Color.dashMaroon)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(viewModel.extractedContent
                                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || viewModel.isGeneratingPDF)
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
        }
        .navigationTitle("URL Extractor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.hasResult {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") { viewModel.clear() }
                        .foregroundColor(Color.dashCrimson)
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.pdfFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

// MARK: — UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems,
                                 applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
