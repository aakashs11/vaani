// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import AppKit
import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 34
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
