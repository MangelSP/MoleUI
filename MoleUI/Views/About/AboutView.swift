import SwiftUI

struct AboutView: View {
    @EnvironmentObject var appState: AppState

    @State private var installPath = "…"
    @State private var snapshotState: SnapshotState = .idle
    enum SnapshotState { case idle, working, saved, failed }

    // Mole (upstream)
    private let moleRepo = URL(string: "https://github.com/tw93/mole")!
    private let moleLicense = URL(string: "https://github.com/tw93/mole/blob/main/LICENSE")!

    // Developer
    private let github = URL(string: "https://github.com/MangelSP")!
    private let avatar = URL(string: "https://github.com/MangelSP.png")!
    private let apps: [(String, String, String)] = [
        ("Portfolio", "https://mangeldev.vercel.app/", "globe"),
        ("Domino (DomiKapikua)", "https://domikapikua.vercel.app/", "square.grid.3x3"),
        ("Anota Domino", "https://anota-domino.vercel.app/", "pencil.and.list.clipboard"),
        ("Adivina & Aprende (kids)", "https://adivinar-kids.vercel.app/", "sparkles"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                // Responsive: 1 column when narrow, 2+ on wide windows — fills the space.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 16)],
                          alignment: .leading, spacing: 16) {
                    developer
                    installAndUpdate
                    poweredByMole
                    snapshot
                }
                licenseFooter
            }
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle("About")
        .task { installPath = await MoleService.shared.installLocation() ?? "Not found" }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Image("MoleLogo").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 76, height: 76).foregroundStyle(.tint)
            Text("MoleUI").font(.largeTitle.bold())
            Text("A native macOS interface for the Mole maintenance CLI").foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var poweredByMole: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Powered by Mole", systemImage: "bolt.heart").font(.title3.bold())
                Text("All system analysis and cleanup is performed by **Mole (`mo`)**, the open-source tool by **tw93**. MoleUI is an independent front end for the community — free, non-commercial, and open source.")
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: moleRepo) { Label("github.com/tw93/mole", systemImage: "arrow.up.right.square") }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }

    private var developer: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("GUI developed by", systemImage: "hammer").font(.title3.bold())
                HStack(spacing: 14) {
                    AsyncImage(url: avatar) { img in img.resizable().scaledToFill() } placeholder: {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                    }
                    .frame(width: 60, height: 60).clipShape(Circle())
                    .overlay(Circle().stroke(.tint.opacity(0.4), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mangel (MangelSP)").font(.headline)
                        Text("Graphical interface developer").font(.callout).foregroundStyle(.secondary)
                        Link(destination: github) { Label("github.com/MangelSP", systemImage: "arrow.up.right") }
                            .font(.callout)
                    }
                    Spacer()
                }
                Divider()
                Text("More projects").font(.subheadline.bold()).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(apps, id: \.1) { app in
                        Link(destination: URL(string: app.1)!) {
                            Label(app.0, systemImage: app.2).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }

    private var installAndUpdate: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Mole installation", systemImage: "shippingbox").font(.title3.bold())
                DetailRow(label: "Version", value: appState.moVersion.isEmpty ? "unknown" : appState.moVersion)
                DetailRow(label: "Location", value: installPath, mono: true)
                HStack {
                    Button { TerminalHandoff.run("mo update") } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button { TerminalHandoff.run("mo update --force") } label: {
                        Label("Repair / Reinstall", systemImage: "wrench.and.screwdriver")
                    }
                }
                Text("Updates run in Terminal via `mo update` — use this if Mole starts erroring.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }

    private var snapshot: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Audit snapshot", systemImage: "doc.badge.arrow.up").font(.title3.bold())
                Text("Export a full JSON snapshot (system status + listening ports) for auditing.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        snapshotState = .working
                        Task { snapshotState = await SnapshotService.export() ? .saved : .failed }
                    } label: { Label("Export JSON Snapshot", systemImage: "square.and.arrow.up") }
                    switch snapshotState {
                    case .working: ProgressView().controlSize(.small)
                    case .saved: Label("Saved", systemImage: "checkmark.circle").foregroundStyle(.green).font(.caption)
                    case .failed: Label("Cancelled / failed", systemImage: "xmark.circle").foregroundStyle(.secondary).font(.caption)
                    case .idle: EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }

    private var licenseFooter: some View {
        VStack(spacing: 6) {
            Link(destination: moleLicense) {
                Label("Licensed under GPL v3 — same as Mole", systemImage: "doc.text")
            }
            .font(.callout)
            Text("Free for the community. Not affiliated with or endorsed by the Mole project.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 4).padding(.bottom, 20)
    }
}
