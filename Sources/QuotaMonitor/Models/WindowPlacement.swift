import Foundation
import CoreGraphics

enum WindowPlacement {
    static func visibleFrame(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard let screen = screens.max(by: { intersectionArea(frame, $0) < intersectionArea(frame, $1) }) else { return frame }
        var result = frame
        result.origin.x = max(screen.minX, min(frame.minX, screen.maxX - frame.width))
        result.origin.y = max(screen.minY, min(frame.minY, screen.maxY - frame.height))
        return result
    }
    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
