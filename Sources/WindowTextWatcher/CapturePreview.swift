import SwiftUI

struct CapturePreview: View {
    let image: CGImage?
    @Binding var region: CGRect

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.88))

                if let image {
                    Image(
                        decorative: image,
                        scale: 1,
                        orientation: .up
                    )
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                    selectionOverlay(
                        geometrySize: geometry.size,
                        image: image
                    )

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(selectionGesture(
                            geometrySize: geometry.size,
                            image: image
                        ))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 34))
                        Text("캡처를 시작하면 여기에 미리보기가 표시됩니다.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func selectionOverlay(
        geometrySize: CGSize,
        image: CGImage
    ) -> some View {
        let mapper = RegionMapper(
            viewSize: geometrySize,
            imageSize: CGSize(width: image.width, height: image.height)
        )
        let selectionRect = mapper.viewRect(
            fromTopLeftNormalized: region
        )

        Rectangle()
            .fill(Color.accentColor.opacity(0.15))
            .overlay {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(
                width: selectionRect.width,
                height: selectionRect.height
            )
            .position(
                x: selectionRect.midX,
                y: selectionRect.midY
            )
            .allowsHitTesting(false)
    }

    private func selectionGesture(
        geometrySize: CGSize,
        image: CGImage
    ) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let mapper = RegionMapper(
                    viewSize: geometrySize,
                    imageSize: CGSize(width: image.width, height: image.height)
                )
                let newRegion = mapper.normalizedRect(
                    from: value.startLocation,
                    to: value.location
                )

                if newRegion.width >= 0.002,
                   newRegion.height >= 0.002 {
                    region = newRegion
                }
            }
    }
}
