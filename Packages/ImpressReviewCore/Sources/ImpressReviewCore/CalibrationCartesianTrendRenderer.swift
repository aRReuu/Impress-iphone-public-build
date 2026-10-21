#if canImport(UIKit)
import UIKit

/// The only Cartesian calibration painter used by both the in-App UIKit chart
/// and WidgetKit's SwiftUI image. Geometry, ticks, gaps and strokes are identical.
/// No score calculation or private journal access takes place in this renderer.
public struct CalibrationCartesianPalette {
    public let axis: UIColor
    public let secondary: UIColor
    public let accent: UIColor

    public init(axis: UIColor, secondary: UIColor, accent: UIColor) {
        self.axis = axis
        self.secondary = secondary
        self.accent = accent
    }

    /// Mirrors ImpressV3Appearance: separator / secondaryLabel / systemBlue.
    public static let semantic = CalibrationCartesianPalette(
        axis: .separator, secondary: .secondaryLabel, accent: .systemBlue)
}

public enum CalibrationCartesianTrendRenderer {
    public static func draw(in rect: CGRect,
                            context: CGContext,
                            values: [Double?],
                            smooth: [Double?],
                            tickLabels: [String],
                            palette: CalibrationCartesianPalette,
                            font: UIFont,
                            traitCollection: UITraitCollection) {
        let box = CGRect(x: 32, y: 12, width: max(1, rect.width - 44),
                         height: max(1, rect.height - 40))
        let all = (values + smooth).compactMap { $0 }
        let ceiling = max(1.0, ceil(all.map(abs).max() ?? 1.0))
        let y: (Double) -> CGFloat = { value in
            box.midY - CGFloat(value / ceiling) * box.height * 0.46
        }
        let axis = palette.axis.resolvedColor(with: traitCollection)
        let muted = palette.secondary.resolvedColor(with: traitCollection)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: muted
        ]
        // Explicit Cartesian axes and simple positive/zero/negative y ticks.
        context.setLineWidth(1)
        context.setStrokeColor(axis.cgColor)
        context.move(to: CGPoint(x: box.minX, y: box.minY))
        context.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        context.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        context.strokePath()
        for number in [-ceiling, 0, ceiling] {
            let lineY = y(number)
            context.setStrokeColor(axis.withAlphaComponent(number == 0 ? 0.8 : 0.4).cgColor)
            context.move(to: CGPoint(x: box.minX, y: lineY))
            context.addLine(to: CGPoint(x: box.maxX, y: lineY))
            context.strokePath()
            let string = String(format: "%+.0f", number) as NSString
            string.draw(at: CGPoint(x: 0, y: lineY - 7), withAttributes: textAttributes)
        }
        if !tickLabels.isEmpty {
            let candidates = Array(Set([0, tickLabels.count/2, tickLabels.count-1])).sorted()
            for index in candidates {
                let value = tickLabels[index] as NSString
                let size = value.size(withAttributes: textAttributes)
                let x = box.minX + box.width * CGFloat(index) /
                    CGFloat(max(1, tickLabels.count-1))
                let origin = CGPoint(x: min(rect.width - size.width, max(0, x - size.width/2)),
                                     y: box.maxY + 5)
                value.draw(at: origin, withAttributes: textAttributes)
            }
        }
        func plot(_ data: [Double?], color: UIColor, width: CGFloat) {
            context.setStrokeColor(color.resolvedColor(with: traitCollection).cgColor)
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            var continuing = false
            for index in data.indices {
                guard let value = data[index] else { continuing = false; continue }
                let x = box.minX + box.width * CGFloat(index) /
                    CGFloat(max(1, data.count - 1))
                let point = CGPoint(x: x, y: y(value))
                if continuing { context.addLine(to: point) }
                else { context.move(to: point) }
                continuing = true
            }
            context.strokePath()
        }
        plot(values, color: palette.secondary, width: 1.4)
        plot(smooth, color: palette.accent, width: 2.8)
        if values.compactMap({ $0 }).count == 1,
           let index = values.firstIndex(where: { $0 != nil }),
           let value = values[index] {
            let x = box.minX + box.width * CGFloat(index) /
                CGFloat(max(1, values.count - 1))
            context.setFillColor(palette.accent.resolvedColor(with: traitCollection).cgColor)
            context.fillEllipse(in: CGRect(x: x-3, y: y(value)-3, width: 6, height: 6))
        }
    }

    /// WidgetKit must use this exact draw() path, not a second Swift Charts
    /// coordinate system that would silently drift from the native controller.
    public static func image(size: CGSize,
                             values: [Double?],
                             smooth: [Double?],
                             tickLabels: [String],
                             palette: CalibrationCartesianPalette = .semantic,
                             font: UIFont = .preferredFont(forTextStyle: .caption2),
                             traitCollection: UITraitCollection) -> UIImage {
        guard size.width >= 1, size.height >= 1 else { return UIImage() }
        return UIGraphicsImageRenderer(size: size).image { renderer in
            draw(in: CGRect(origin: .zero, size: size),
                 context: renderer.cgContext,
                 values: values, smooth: smooth, tickLabels: tickLabels,
                 palette: palette, font: font, traitCollection: traitCollection)
        }
    }
}
#endif
