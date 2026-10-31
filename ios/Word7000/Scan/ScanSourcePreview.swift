import SwiftUI
import UIKit

struct ScanSourcePreview: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.maximumZoomScale = 5
        scroll.backgroundColor = .black
        let view = context.coordinator.imageView
        view.contentMode = .scaleAspectFit
        view.image = image
        view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        // Double-tap zooms in on that spot, and out again.
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ view: UIScrollView, context: Context) {}

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func toggleZoom(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
                return
            }
            let scale = min(scroll.maximumZoomScale, 2.5)
            let point = gesture.location(in: imageView)
            let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
            let target = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
            scroll.zoom(to: target, animated: true)
        }
    }
}
