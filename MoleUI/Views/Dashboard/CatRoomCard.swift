import SwiftUI

/// The cat's room: every object is wired to a live metric, and the cat does whatever the
/// system state calls for. ponytail: fixed-position ZStack of sprites, no physics.
///
///   bed      ← memory    (cat sleeps here when RAM is relaxed)
///   bowl     ← disk      (food shrinks as disk fills; cat eats when disk is healthy)
///   post     ← CPU       (cat plays here under load; hisses when pegged)
///   window   ← network   (lit when online)
///   plant    ← health    (fades as the score drops)
///   yarn     ← ports     (one ball per listening port, up to 6)
///   battery  ← water bowl (fill tracks charge)
struct CatRoomCard: View {
    let s: MoleStatus
    var ports: Int = 0

    private enum Activity { case sleeping, eating, playing, alarmed, strolling }

    private var activity: Activity {
        let cpu = s.cpu.usage, mem = s.memory.usedPercent
        let disk = s.disks.first?.usedPercent ?? 0
        if s.healthScore < 50 || cpu > 90 || mem > 90 || disk > 95 { return .alarmed }
        if cpu > 50 { return .playing }
        if mem < 60 && cpu < 15 { return .sleeping }
        if disk < 85 && cpu < 35 { return .eating }
        return .strolling
    }

    private var caption: String {
        let disk = Int(s.disks.first?.usedPercent ?? 0)
        switch activity {
        case .alarmed:  return "Hissing — something's pegged (CPU \(Int(s.cpu.usage))% · RAM \(Int(s.memory.usedPercent))% · disk \(disk)%)"
        case .playing:  return "Playing on the post — CPU busy at \(Int(s.cpu.usage))%"
        case .sleeping: return "Napping — RAM relaxed at \(Int(s.memory.usedPercent))%"
        case .eating:   return "Eating — disk has room (\(100 - disk)% free)"
        case .strolling: return "Strolling around the room"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pawprint.fill").font(.system(size: 11))
                    Text("CAT ROOM").font(.monoLabel(11)).tracking(1)
                }.foregroundStyle(Theme.emerald)
                Spacer()
                Text(caption).font(.monoLabel(10)).foregroundStyle(activity == .alarmed ? .red : .secondary)
            }
            room.frame(height: 210)
        }
        .moleCard()
    }

    private var room: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                // floor
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Theme.emerald.opacity(0.06), Theme.emerald.opacity(0.14)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 90).offset(y: 120)

                // window ← network
                sprite("RoomWindow", 1.3).offset(x: 16, y: 6)
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill((s.network.contains { $0.isActive } ? Color.cyan : Color.gray).opacity(0.25))
                            .frame(width: 44, height: 70).offset(x: 16 + 40, y: 6 + 62).allowsHitTesting(false)
                    }
                    .help("Network: \(s.network.first { $0.isActive }?.name ?? "offline")")

                // shelf + plant ← health
                sprite("RoomShelf", 1.2).offset(x: w - 150, y: 20)
                sprite("RoomPlant", 1.2).offset(x: w - 60, y: 40)
                    .saturation(Double(s.healthScore) / 100).opacity(0.5 + Double(s.healthScore) / 200)
                    .help("Health score \(s.healthScore)")

                // bed ← memory
                sprite("RoomBed", 1.4).offset(x: w * 0.42, y: 96)
                    .help("Memory \(Int(s.memory.usedPercent))% used")

                // scratching post ← CPU
                sprite("RoomPost", 1.3).offset(x: w * 0.22, y: 40)
                    .help("CPU \(Int(s.cpu.usage))%")

                // bowls ← disk / battery
                let diskFree = 1 - (s.disks.first?.usedPercent ?? 0) / 100
                sprite("RoomBowl", 1.5).offset(x: 40, y: 150)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(width: 80, height: 20 + 40 * diskFree).offset(x: 40 + 32, y: 150 + 56 - 20 * diskFree)
                    }
                    .help("Disk \(Int(diskFree * 100))% free")
                if let b = s.batteries.first {
                    sprite("RoomWater", 1.5).offset(x: 110, y: 154)
                        .opacity(0.4 + 0.6 * Double(b.percent) / 100)
                        .help("Battery \(b.percent)%")
                }

                // yarn ← listening ports
                ForEach(0..<min(ports, 6), id: \.self) { i in
                    sprite("RoomYarn", 1.2).offset(x: w - 200 + CGFloat(i) * 26, y: 176)
                        .hueRotation(.degrees(Double(i) * 50))
                }

                cat(w)
            }
        }
    }

    @ViewBuilder private func cat(_ w: CGFloat) -> some View {
        switch activity {
        case .sleeping: InteractiveCat(mood: .sleep, scale: 2.5).offset(x: w * 0.42 + 20, y: 70)
        case .eating:   InteractiveCat(mood: .eat, scale: 2.5).offset(x: 20, y: 70)
        case .alarmed:  InteractiveCat(mood: .alarm, scale: 2.5).offset(x: w * 0.22 + 70, y: 90)
        case .playing:  InteractiveCat(mood: .walk, scale: 2.5).offset(x: w * 0.22 + 84, y: 100)
        case .strolling: StrollingCat(width: w, y: 100, scale: 2.5)
        }
    }

    private func sprite(_ name: String, _ scale: CGFloat) -> some View {
        Image(name).interpolation(.none).resizable().scaledToFit()
            .frame(height: imageHeight(name) * scale)
    }
    private func imageHeight(_ name: String) -> CGFloat { NSImage(named: name)?.size.height ?? 32 }
}
