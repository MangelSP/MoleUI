import SwiftUI

/// A titled card with a monospaced emerald header — the standard section container.
struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 11))
                Text(title.uppercased()).font(.monoLabel(11)).tracking(1)
                Spacer()
                if let trailing { trailing }
            }
            .foregroundStyle(Theme.emerald)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .moleCard()
    }
}

/// A big rounded readout with a small trailing unit, e.g. 64 %.
struct Readout: View {
    let value: String
    var unit: String? = nil
    var size: CGFloat = 30
    var tint: Color = .primary
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.display(size)).monospacedDigit().foregroundStyle(tint)
            if let unit { Text(unit).font(.monoLabel(12)).foregroundStyle(.secondary) }
        }
    }
}

/// Sparkline for a series of samples (auto-scaled), with a soft fill.
struct Sparkline: View {
    var samples: [Double]
    var tint: Color = Theme.emerald

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count >= 2 {
                ZStack {
                    fillPath(pts, height: geo.size.height)
                        .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                    linePath(pts)
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 34)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard samples.count >= 2 else { return [] }
        let lo = samples.min() ?? 0, hi = samples.max() ?? 1
        let span = max(hi - lo, 0.0001)
        let dx = size.width / CGFloat(samples.count - 1)
        return samples.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * dx, y: 3 + (size.height - 6) * (1 - CGFloat((v - lo) / span)))
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var p = Path(); p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) }; return p
    }

    private func fillPath(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = linePath(pts)
        p.addLine(to: CGPoint(x: pts.last!.x, y: height))
        p.addLine(to: CGPoint(x: pts.first!.x, y: height))
        p.closeSubpath()
        return p
    }
}

/// Vertical bar histogram, e.g. per-core CPU. Values are 0…100.
struct CoreBars: View {
    var values: [Double]
    var body: some View {
        GeometryReader { geo in
            let n = max(values.count, 1)
            let gap: CGFloat = 4
            let w = (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.load(v))
                        .frame(width: w, height: max(3, geo.size.height * CGFloat(v / 100)))
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 44)
    }
}

/// Horizontal meter with a gradient fill (disk, etc.).
struct Meter: View {
    var fraction: Double
    var tint: Color = Theme.sky
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.07))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 10)
    }
}
