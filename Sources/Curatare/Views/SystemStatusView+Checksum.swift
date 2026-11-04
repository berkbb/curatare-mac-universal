// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Dosya Sağlama Toplamı (Checksum / Hash) Hesaplayıcı Paneli

extension SystemStatusView {
    var checksumCalculatorView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.checksumTitle))
                    .font(.title3.bold())
                Text(model.L(.checksumSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Drop & Select Zone
            VStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)

                Text(model.checksumResult?.fileName ?? model.L(.checksumDropPrompt))
                    .font(.headline)

                if let res = model.checksumResult {
                    Text(DiskSpace.formatBytes(res.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(model.L(.checksumChooseFile)) {
                    chooseFileForChecksum()
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard let first = urls.first else { return false }
                model.computeChecksum(for: first)
                return true
            }

            if model.isCalculatingChecksum {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(model.L(.statusScanning))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let result = model.checksumResult {
                VStack(alignment: .leading, spacing: 12) {
                    checksumRow(title: "MD5", hash: result.md5)
                    checksumRow(title: "SHA-1", hash: result.sha1)
                    checksumRow(title: "SHA-256", hash: result.sha256)

                    Divider()

                    // Compare & Verify
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(model.L(.checksumComparePlaceholder), text: $model.checksumExpectedHash)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())

                        if !model.checksumExpectedHash.trimmingCharacters(in: .whitespaces).isEmpty {
                            let (isMatch, algo) = result.verify(expected: model.checksumExpectedHash)
                            if isMatch, let algo = algo {
                                Label(model.LF(.checksumMatch, algo), systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else {
                                Label(model.L(.checksumMismatch), systemImage: "xmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }

            Spacer()
        }
    }

    private func checksumRow(title: String, hash: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .frame(width: 64, alignment: .leading)
            Text(hash)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Spacer()
            Button {
                model.copyToClipboard(hash, label: "\(model.L(.buttonCopied)): \(title)")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
    }

    private func chooseFileForChecksum() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.computeChecksum(for: url)
        }
    }
}
