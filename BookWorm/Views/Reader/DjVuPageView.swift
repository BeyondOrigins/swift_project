import SwiftUI
import djvu

struct DjVuPageView: View {
    let book: Book
    let pageIndex: Int
    
    @State private var pageImage: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if let image = pageImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = max(1.0, min(lastScale * value.magnification, 5.0))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= 1.0 {
                                        withAnimation { offset = .zero }
                                        lastOffset = .zero
                                    }
                                }
                        )
                        .simultaneousGesture(
                            scale > 1.0
                            ? DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                            : nil
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                }
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Rendering page \(pageIndex + 1)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 500)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadPage() } }
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 500)
            }
        }
        .task(id: pageIndex) {
            // Cancel zoom when on page change
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            await loadPage()
        }
    }
    
    private func loadPage() async {
        isLoading = true
        errorMessage = nil
        
        guard let path = book.localFilePath else {
            errorMessage = "Book file not found"
            isLoading = false
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "File does not exist at path"
            isLoading = false
            return
        }
        
        let page = pageIndex
        
        let image = await Task.detached(priority: .userInitiated) {
            () -> UIImage? in
            do {
                let djvuDoc = try Djvu(url: fileURL)
                
                let rendered = try djvuDoc.getImage(page: page, dpi: 300)
                return rendered
            } catch {
                print("DjVu render error page \(page): \(error)")
                return nil
            }
        }.value
        
        if let image = image {
            pageImage = image
        } else {
            errorMessage = "Failed to render page \(pageIndex + 1)"
        }
        
        isLoading = false
    }
}
