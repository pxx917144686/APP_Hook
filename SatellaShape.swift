import UIKit

@available(iOS 15, *)
final class SatellaShape: UIView {
    override func draw(_ rect: CGRect) {
        let size: CGSize = rect.size

        let bodyPath = UIBezierPath(ovalIn: CGRect(
            x: size.width * 0.3,
            y: size.height * 0.25,
            width: size.width * 0.4,
            height: size.height * 0.5
        ))
        UIColor.systemGreen.setFill()
        bodyPath.fill()
        
        let headPath = UIBezierPath(ovalIn: CGRect(
            x: size.width * 0.35,
            y: size.height * 0.15,
            width: size.width * 0.3,
            height: size.height * 0.25
        ))
        UIColor.systemGreen.setFill()
        headPath.fill()
        
        let leftAntenna = UIBezierPath()
        leftAntenna.move(to: CGPoint(x: size.width * 0.4, y: size.height * 0.2))
        leftAntenna.addLine(to: CGPoint(x: size.width * 0.25, y: size.height * 0.1))
        leftAntenna.lineWidth = 2
        UIColor.black.setStroke()
        leftAntenna.stroke()
        
        let rightAntenna = UIBezierPath()
        rightAntenna.move(to: CGPoint(x: size.width * 0.6, y: size.height * 0.2))
        rightAntenna.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.1))
        rightAntenna.lineWidth = 2
        UIColor.black.setStroke()
        rightAntenna.stroke()
        
        for i in 0..<3 {
            let legPath = UIBezierPath()
            let yPos = size.height * (0.35 + Double(i) * 0.15)
            legPath.move(to: CGPoint(x: size.width * 0.3, y: yPos))
            legPath.addLine(to: CGPoint(x: size.width * 0.15, y: yPos + size.height * 0.05))
            legPath.lineWidth = 2
            UIColor.black.setStroke()
            legPath.stroke()
        }
        
        for i in 0..<3 {
            let legPath = UIBezierPath()
            let yPos = size.height * (0.35 + Double(i) * 0.15)
            legPath.move(to: CGPoint(x: size.width * 0.7, y: yPos))
            legPath.addLine(to: CGPoint(x: size.width * 0.85, y: yPos + size.height * 0.05))
            legPath.lineWidth = 2
            UIColor.black.setStroke()
            legPath.stroke()
        }

        let leftEye = UIBezierPath(ovalIn: CGRect(
            x: size.width * 0.42,
            y: size.height * 0.22,
            width: size.width * 0.06,
            height: size.height * 0.06
        ))
        UIColor.black.setFill()
        leftEye.fill()
        
        let rightEye = UIBezierPath(ovalIn: CGRect(
            x: size.width * 0.52,
            y: size.height * 0.22,
            width: size.width * 0.06,
            height: size.height * 0.06
        ))
        UIColor.black.setFill()
        rightEye.fill()
    }
}
