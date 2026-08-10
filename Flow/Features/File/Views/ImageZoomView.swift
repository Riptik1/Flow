//
//  ImageZoomView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI
import PDFKit

struct ImageZoomView: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> ImageZoomVC { ImageZoomVC(image: image) }
    func updateUIViewController(_ vc: ImageZoomVC, context: Context) {}
}

final class ImageZoomVC: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var initialLayoutDone = false

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !initialLayoutDone else { return }
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        initialLayoutDone = true
        setInitialImageFrame()
    }

    private func setInitialImageFrame() {
        let containerSize = scrollView.bounds.size
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let widthRatio  = containerSize.width  / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth  = imageSize.width  * scale
        let scaledHeight = imageSize.height * scale
        let x = (containerSize.width  - scaledWidth)  / 2
        let y = (containerSize.height - scaledHeight) / 2

        imageView.frame = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        scrollView.contentSize = containerSize
        scrollView.zoomScale = 1.0
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }

    private func centerImageView() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        frameToCenter.origin.x = frameToCenter.width < boundsSize.width
            ? (boundsSize.width - frameToCenter.width) / 2 : 0
        frameToCenter.origin.y = frameToCenter.height < boundsSize.height
            ? (boundsSize.height - frameToCenter.height) / 2 : 0
        imageView.frame = frameToCenter
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let tapPoint = recognizer.location(in: imageView)
            let zoomSize = CGSize(
                width:  scrollView.bounds.width  / scrollView.maximumZoomScale,
                height: scrollView.bounds.height / scrollView.maximumZoomScale
            )
            let zoomRect = CGRect(
                x: tapPoint.x - zoomSize.width  / 2,
                y: tapPoint.y - zoomSize.height / 2,
                width:  zoomSize.width,
                height: zoomSize.height
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}

struct PDFViewer: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor = UIColor(white: 0.08, alpha: 1)
        v.document = PDFDocument(url: url)
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
