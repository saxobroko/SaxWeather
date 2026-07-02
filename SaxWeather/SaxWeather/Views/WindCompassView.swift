import SwiftUI

/// Compact or full wind-direction compass with a rotating arrow and
/// cardinal label. Reused on the main details card and in `WindCard`.
struct WindCompassView: View {
    enum Size {
        case compact
        case regular

        var diameter: CGFloat {
            switch self {
            case .compact: return 28
            case .regular: return 80
            }
        }

        var arrowFrame: CGFloat {
            switch self {
            case .compact: return 14
            case .regular: return 40
            }
        }

        var ringLabelOffset: CGFloat {
            diameter / 2
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    let direction: Double
    var size: Size = .regular
    var showCardinalsOnRing: Bool = true
    var showCardinalLabel: Bool = true

    private var cardinal: String {
        Self.cardinalAbbreviation(for: direction)
    }

    var body: some View {
        HStack(spacing: size == .compact ? 4 : 0) {
            compass
            if showCardinalLabel && size == .compact {
                Text(cardinal)
                    .accessibleFont(size: 13, weight: .semibold)
                    .accessibleContrast()
                    .foregroundStyle(labelColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("Wind from \(cardinal), \(Int(direction.rounded())) degrees")
        )
    }

    private var compass: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: size == .compact ? 1.5 : 2)
                .frame(width: size.diameter, height: size.diameter)

            if showCardinalsOnRing && size == .regular {
                ForEach([0, 90, 180, 270], id: \.self) { deg in
                    Text(["N", "E", "S", "W"][deg / 90])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .offset(y: -size.ringLabelOffset)
                        .rotationEffect(.degrees(Double(deg)))
                }
            }

            WindDirectionArrow()
                .stroke(arrowColor, style: StrokeStyle(
                    lineWidth: size == .compact ? 2 : 3,
                    lineCap: .round
                ))
                .frame(width: size.arrowFrame, height: size.arrowFrame)
                .rotationEffect(.degrees(direction))
                .accessibleAnimation(.easeInOut(duration: 0.35), value: direction)
        }
    }

    private var ringColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.25)
            : Color.black.opacity(0.15)
    }

    private var arrowColor: Color {
        size == .compact ? .accentColor : .accentColor
    }

    private var labelColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.9)
            : Color.black.opacity(0.8)
    }

    static func cardinalAbbreviation(for degrees: Double) -> String {
        let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45.0) % labels.count
        return labels[index]
    }
}

struct WindDirectionArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        return path
    }
}
