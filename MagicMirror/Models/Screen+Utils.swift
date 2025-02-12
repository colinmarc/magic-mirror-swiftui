import MMClientCommon
import OSLog

extension CGSize {
    func makeEven() -> CGSize {
        var w = Int(self.width.rounded())
        var h = Int(self.height.rounded())

        if w % 2 != 0 {
            w += 1
        }

        if h % 2 != 0 {
            h += 1
        }

        return CGSize(width: w, height: h)
    }

}

#if os(macOS)
    import AppKit

    extension NSScreen {
        var pixelScale: PixelScale {
            let scale: PixelScale
            if self.backingScaleFactor <= 1.0 {
                scale = .one
            } else {
                let numerator = UInt32((self.backingScaleFactor * 6.0).rounded())
                let denominator: UInt32 = 6

                if (numerator % denominator) == 0 {
                    scale = PixelScale(numerator: numerator / denominator, denominator: 1)
                } else {
                    scale = PixelScale(numerator: numerator, denominator: denominator)
                }
            }

            Logger.general.debug("pixel scale is \(String(describing: scale))")
            return scale
        }

        var attachmentDimensions: CGSize {
            // To match the OS math for a fullscreen window, we need to make the
            // frame dimensions even *before* multiplying by the backing scale.
            let rect = CGRect(origin: .zero, size: self.visibleFrame.size.makeEven())
            return convertRectToBacking(rect).size.makeEven()
        }
    }
#endif
