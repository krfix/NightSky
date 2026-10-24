import SwiftUI

struct Star {
    let x: CGFloat      // normalized 0...1
    let y: CGFloat
    let size: CGFloat
    let phase: Double
    let speed: Double
    let tint: Color
}

struct ShootingStar {
    let start: Date
    let origin: CGPoint // normalized 0...1
    let angle: Double
    let length: CGFloat
    let duration: Double
}

/// Plain reference type: the TimelineView redraws every frame anyway,
/// so nothing here needs to be observable.
final class Sky {
    let stars: [Star]
    var shootingStars: [ShootingStar] = []
    private var nextShot = Date().addingTimeInterval(1.5)

    init(count: Int = 280) {
        let tints: [Color] = [.white, .white, .white,
                              Color(red: 0.75, green: 0.85, blue: 1.0),
                              Color(red: 1.0, green: 0.92, blue: 0.8)]
        stars = (0..<count).map { _ in
            Star(x: .random(in: 0...1),
                 y: .random(in: 0...1),
                 size: .random(in: 0.6...2.6),
                 phase: .random(in: 0...(2 * .pi)),
                 speed: .random(in: 0.4...2.2),
                 tint: tints.randomElement()!)
        }
    }

    func update(now: Date) {
        shootingStars.removeAll { now.timeIntervalSince($0.start) > $0.duration }
        if now >= nextShot {
            launch(at: CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.0...0.4)), now: now)
            nextShot = now.addingTimeInterval(.random(in: 2...6))
        }
    }

    func launch(at origin: CGPoint, now: Date = Date()) {
        // Mostly horizontal, heading down-left or down-right.
        let slope = Double.random(in: 0.35...0.9)
        let angle = Bool.random() ? slope : .pi - slope
        shootingStars.append(ShootingStar(start: now,
                                          origin: origin,
                                          angle: angle,
                                          length: .random(in: 0.12...0.25),
                                          duration: .random(in: 0.8...1.4)))
    }
}

struct ContentView: View {
    @State private var sky = Sky()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let now = timeline.date
                    sky.update(now: now)
                    drawStars(&ctx, size: size, t: now.timeIntervalSinceReferenceDate)
                    drawMoon(&ctx, size: size)
                    drawShootingStars(&ctx, size: size, now: now)
                }
            }
            .background(
                LinearGradient(colors: [Color(red: 0.01, green: 0.02, blue: 0.08),
                                        Color(red: 0.04, green: 0.06, blue: 0.20),
                                        Color(red: 0.12, green: 0.10, blue: 0.30)],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .bottom) {
                Text("Night Sky")
                    .font(.system(size: 28, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.bottom, 48)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    sky.launch(at: CGPoint(x: value.location.x / max(geo.size.width, 1),
                                           y: value.location.y / max(geo.size.height, 1)))
                }
            )
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func drawStars(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for star in sky.stars {
            let twinkle = 0.55 + 0.45 * sin(t * star.speed + star.phase)
            let r = star.size * CGFloat(0.8 + 0.4 * twinkle)
            let p = CGPoint(x: star.x * size.width, y: star.y * size.height)
            var c = ctx
            c.opacity = twinkle
            c.fill(Path(ellipseIn: CGRect(x: p.x - r / 2, y: p.y - r / 2, width: r, height: r)),
                   with: .color(star.tint))
            if star.size > 2.1 {
                c.opacity = twinkle * 0.25
                c.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.5, y: p.y - r * 1.5, width: r * 3, height: r * 3)),
                       with: .color(star.tint))
            }
        }
    }

    private func drawMoon(_ ctx: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) * 0.09
        let center = CGPoint(x: size.width * 0.76, y: size.height * 0.16)
        let moonRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let moonColor = Color(red: 1.0, green: 0.96, blue: 0.85)

        ctx.drawLayer { glow in
            glow.addFilter(.blur(radius: radius * 0.6))
            glow.opacity = 0.35
            glow.fill(Path(ellipseIn: moonRect.insetBy(dx: -radius * 0.2, dy: -radius * 0.2)), with: .color(moonColor))
        }
        ctx.drawLayer { layer in
            layer.fill(Path(ellipseIn: moonRect), with: .color(moonColor))
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: moonRect.offsetBy(dx: -radius * 0.55, dy: -radius * 0.25)), with: .color(.black))
        }
    }

    private func drawShootingStars(_ ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let travel = max(size.width, size.height) * 0.5
        for s in sky.shootingStars {
            let p = CGFloat(min(max(now.timeIntervalSince(s.start) / s.duration, 0), 1))
            let dx = CGFloat(cos(s.angle)), dy = CGFloat(sin(s.angle))
            let origin = CGPoint(x: s.origin.x * size.width, y: s.origin.y * size.height)
            let head = CGPoint(x: origin.x + dx * travel * p, y: origin.y + dy * travel * p)
            let tailLen = s.length * size.width * min(p * 3, 1)
            let tail = CGPoint(x: head.x - dx * tailLen, y: head.y - dy * tailLen)

            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)

            var c = ctx
            c.opacity = p < 0.75 ? 1 : Double((1 - p) / 0.25)
            c.stroke(path,
                     with: .linearGradient(Gradient(colors: [.white.opacity(0), .white]),
                                           startPoint: tail, endPoint: head),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))
            c.fill(Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)), with: .color(.white))
        }
    }
}
