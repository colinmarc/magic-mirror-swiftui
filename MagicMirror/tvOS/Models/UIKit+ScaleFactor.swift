import MetalKit
import UIKit

extension MTKView {
    func convertToBacking(_ point: CGPoint) -> CGPoint {
        return point
    }

    func convertFromBacking(_ point: CGPoint) -> CGPoint {
        return point
    }
}

extension UIWindow {
    var backingScaleFactor: Double {
        1
    }
}
