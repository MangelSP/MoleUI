import SwiftUI

/// Pixel-art cat mascot animated from horizontal sprite strips. ponytail: TimelineView + crop,
/// no animation framework. `mood` picks the strip; call sites map system state → mood.
/// One switch for every cat (sidebar, loaders, room). Persisted in UserDefaults.
enum CatSettings {
    static let key = "catEnabled"
    static let skinKey = "catSkin"
    static let skins = ["Orange", "Calico", "Tabby"]
    static var enabled: Bool { UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key) }
}

struct PixelCat: View {
    @AppStorage(CatSettings.key) private var enabled = true
    /// Every skin has 4-frame 32px strips: Back, Walk, Front, WalkL, Idle, Groom, (Lie, Sleep).
    /// Calico has no Lie/Sleep; those fall back to Idle at a slow rate.
    enum Mood {
        case walk, sleep, eat, alarm, box, pet, idle
        func sheet(skin: String) -> (name: String, frames: Int, size: CGFloat, fps: Double) {
            let has = { (row: String) in NSImage(named: skin + row) != nil }
            switch self {
            case .walk:  return (skin + "Walk", 4, 32, 6)
            case .sleep: return has("Sleep") ? (skin + "Sleep", 4, 32, 1.5) : (skin + "Idle", 4, 32, 1)
            case .eat:   return (skin + "Groom", 4, 32, 4)
            case .alarm: return (skin + "Front", 4, 32, 10)     // pacing straight at you
            case .box:   return has("Lie") ? (skin + "Lie", 4, 32, 3) : (skin + "Idle", 4, 32, 3)
            case .pet:   return (skin + "Groom", 4, 32, 6)
            case .idle:  return (skin + "Idle", 4, 32, 3)
            }
        }
    }
    var mood: Mood
    var scale: CGFloat = 2
    @AppStorage(CatSettings.skinKey) private var skin = "Orange"

    var body: some View {
        if enabled { animated } else { ProgressView().controlSize(.small).frame(height: 32 * scale) }
    }

    private var animated: some View {
        let s = mood.sheet(skin: skin)
        return TimelineView(.periodic(from: .now, by: 1 / s.fps)) { ctx in
            let frame = Int(ctx.date.timeIntervalSinceReferenceDate * s.fps) % s.frames
            Image(s.name)
                .interpolation(.none)
                .resizable()
                .frame(width: s.size * CGFloat(s.frames) * scale, height: s.size * scale)
                .offset(x: -CGFloat(frame) * s.size * scale)
                .frame(width: s.size * scale, height: s.size * scale, alignment: .leading)
                .clipped()
        }
        .accessibilityHidden(true)
    }

    /// Map health/load to a mood: red → hissing, excellent+quiet → asleep, otherwise strolling.
    static func mood(health: Int, cpu: Double, memory: Double) -> Mood {
        if health < 50 || cpu > 90 || memory > 90 { return .alarm }
        if health >= 90 && cpu < 20 { return .sleep }
        return .idle
    }
}


/// Cat you can interact with: click = pet (purrs for a few seconds), hover shows the mood.
struct InteractiveCat: View {
    var mood: PixelCat.Mood
    var scale: CGFloat = 2
    var caption: String? = nil
    @State private var petUntil = Date.distantPast
    @State private var hearts = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let petting = ctx.date < petUntil
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    PixelCat(mood: petting ? .pet : mood, scale: scale)
                    if petting {
                        Text("♥").font(.system(size: 12 * scale / 2)).foregroundStyle(.pink)
                            .offset(x: 4, y: -4).transition(.scale)
                    }
                }
                if let caption {
                    Text(petting ? "purr… (\(hearts))" : caption)
                        .font(.monoLabel(9)).foregroundStyle(petting ? .pink : mood == .alarm ? .red : .secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { petUntil = Date().addingTimeInterval(3); hearts += 1 }
        .help(mood == .alarm ? "The cat is upset — check CPU / RAM / disk" : "Click to pet the cat")
    }
}
