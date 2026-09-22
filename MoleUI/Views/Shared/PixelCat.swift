import SwiftUI

/// Pixel-art cat mascot animated from horizontal sprite strips. ponytail: TimelineView + crop,
/// no animation framework. `mood` picks the strip; call sites map system state → mood.
struct PixelCat: View {
    enum Mood {
        case walk, sleep, eat, alarm, box
        var sheet: (name: String, frames: Int, size: CGFloat, fps: Double) {
            switch self {
            case .walk:  return ("CatWalk", 10, 32, 8)
            case .sleep: return ("CatSleep", 4, 64, 2)
            case .eat:   return ("CatEat", 4, 64, 4)
            case .alarm: return ("CatAlarm", 2, 64, 5)
            case .box:   return ("CatBox", 4, 32, 4)
            }
        }
    }
    var mood: Mood
    var scale: CGFloat = 2

    var body: some View {
        let s = mood.sheet
        TimelineView(.periodic(from: .now, by: 1 / s.fps)) { ctx in
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
