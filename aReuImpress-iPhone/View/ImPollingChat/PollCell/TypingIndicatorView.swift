import UIKit

class TypingIndicatorView: UIView {

    private let dot1 = CALayer()
    private let dot2 = CALayer()
    private let dot3 = CALayer()

    private var dots: [CALayer] {
        return [dot1, dot2, dot3]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDots()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDots()
    }

    private func setupDots() {
        let dotSize: CGFloat = 8.0
        let dotColor = contentColor.cgColor

        dots.forEach {
            $0.bounds.size = CGSize(width: dotSize, height: dotSize)
            $0.backgroundColor = dotColor
            $0.cornerRadius = dotSize / 2
            layer.addSublayer($0)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let dotSize = dot1.bounds.width
        let spacing: CGFloat = 5.0
        let totalWidth = (dotSize * 3) + (spacing * 2)
        
        let startX = (bounds.width - totalWidth) / 2
        let yPos = (bounds.height - dotSize) / 2

        dot1.position = CGPoint(x: startX + dotSize / 2, y: yPos + dotSize / 2)
        dot2.position = CGPoint(x: startX + dotSize * 1.5 + spacing, y: yPos + dotSize / 2)
        dot3.position = CGPoint(x: startX + dotSize * 2.5 + spacing * 2, y: yPos + dotSize / 2)
    }

    func startAnimating() {
        var delay: TimeInterval = 0
        for dot in dots {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.addAnimation(to: dot)
            }
            delay += 0.3
        }
    }

    func stopAnimating() {
        dots.forEach { $0.removeAllAnimations() }
    }

    private func addAnimation(to dot: CALayer) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 0.6
        animation.repeatCount = .infinity
        animation.autoreverses = true
        dot.add(animation, forKey: "opacityAnimation")
    }
}
