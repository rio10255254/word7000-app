import SwiftUI

extension View {
    /// Content scrolling under the top of a scroll view fades out over
    /// `height` points instead of being cut off by a hard line.
    func softTopScrollEdge(_ height: CGFloat = 14) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
                Rectangle().fill(.black)
            }
        }
    }
}
