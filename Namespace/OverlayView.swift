// SwiftUI overlay that draws a tappable name label under each Space thumbnail, using
// the empirically-observed Mission Control Spaces-bar geometry constants below. If Apple
// shifts the bar layout, tune the constants in one place here.

import SwiftUI

struct OverlayView: View {
    let spaces: [Space]
    let names: [String]
    let screenFrame: CGRect
    let onTap: (UInt64) -> Void

    // Mission Control's Spaces Bar geometry — empirically observed.
    // If Apple shifts the layout, tune these in one place.
    private let barTopInset: CGFloat = 12     // gap between top-of-screen and bar
    private let barHeight: CGFloat = 130      // total bar height
    private let thumbInsetV: CGFloat = 18     // padding inside bar above/below thumbs
    private let thumbGap: CGFloat = 12
    private let labelTopGap: CGFloat = 6      // space between thumb bottom and label

    private var thumbHeight: CGFloat { barHeight - 2 * thumbInsetV }
    private var thumbAspect: CGFloat {
        guard screenFrame.height > 0 else { return 16.0 / 10.0 }
        return screenFrame.width / screenFrame.height
    }
    private var thumbWidth: CGFloat { thumbHeight * thumbAspect }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            HStack(spacing: thumbGap) {
                ForEach(Array(spaces.enumerated()), id: \.element.id64) { _, space in
                    Button {
                        onTap(space.id64)
                    } label: {
                        Text(displayName(for: space))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .frame(width: thumbWidth)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.65))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, barTopInset + barHeight + labelTopGap)
        }
        .frame(width: screenFrame.width, height: screenFrame.height, alignment: .top)
    }

    private func displayName(for space: Space) -> String {
        if let idx = spaces.firstIndex(of: space), idx < names.count {
            return names[idx]
        }
        return "Space"
    }
}
