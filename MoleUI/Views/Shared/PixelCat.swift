import SwiftUI

/// Pixel-art cat mascot animated from horizontal sprite strips. ponytail: TimelineView + crop,
/// no animation framework. `mood` picks the strip; call sites map system state → mood.
/// One switch for every cat (sidebar, loaders, room). Persisted in UserDefaults.
enum CatSettings {
    static let key = "catEnabled"
    static var enabled: Bool { UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key) }
}

struct PixelCat: View {
    @AppStorage(CatSettings.key) private var enabled = true
    enum Mood {
        case walk, sleep, eat, alarm, box, pet
        // ponytail: the "walk" strip is really a sitting tail-swish; motion comes from the caller (see Stroll).
        var sheet: (name: String, frames: Int, size: CGFloat, fps: Double) {
            switch self {
            case .walk:  return ("CatWalk", 10, 32, 8)
            case .sleep: return ("CatSleep", 4, 64, 2)
            case .eat:   return ("CatEat", 4, 64, 4)
            case .alarm: return ("CatAlarm", 2, 64, 5)
            case .box:   return ("CatBox", 4, 32, 4)
            case .pet:   return ("CatEat", 4, 64, 6)     // happy munching = being petted
            }
        }
    }
    var mood: Mood
    var scale: CGFloat = 2

    var body: some View {
        if enabled { animated } else { ProgressView().controlSize(.small).frame(height: mood.sheet.size * scale) }
    }

    private var animated: some View {
        let s = mood.sheet
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
        return .walk
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

/// Sitting cat that strolls back and forth with a little bob so it reads as walking.
struct StrollingCat: View {
    var width: CGFloat
    var y: CGFloat
    var scale: CGFloat = 2
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 8) / 8
            let x = 60 + (width - 200) * (phase < 0.5 ? phase * 2 : 2 - phase * 2)   // ping-pong
            let bob = abs(sin(t * 8)) * 3                                             // step bounce
            PixelCat(mood: .walk, scale: scale)
                .scaleEffect(x: phase < 0.5 ? 1 : -1, y: 1 - bob / 40)
                .offset(x: x, y: y - bob)
        }
    }
}
