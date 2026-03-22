//
//  PDFPageView.swift
//  BookWorm
//
//  Created by beyondorigins on 22.03.2026.
//

import SwiftUI
import PDFKit

struct PDFPageImageView: View {
    let book: Book
    let pageIndex: Int
    
    @State private var pageImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if let image = pageImage {
                let aspect = image.size.height / image.size.width
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: UIScreen.main.bounds.width * aspect)
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
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Rendering page \(pageIndex + 1)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 500)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("Could not render page \(pageIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 500)
            }
        }
        .task(id: pageIndex) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            await loadPage()
        }
    }
    
    private func loadPage() async {
        isLoading = true
        
        guard let path = book.localFilePath else {
            isLoading = false
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        let page = pageIndex
        
        let image = await Task.detached(priority: .userInitiated) {
            () -> UIImage? in
            guard let document = PDFDocument(url: fileURL),
                  let pdfPage = document.page(at: page) else {
                return nil
            }
            
            let pageRect = pdfPage.bounds(for: .mediaBox)
            
            let scaleFactor: CGFloat = 2.0
            let renderSize = CGSize(
                width: pageRect.width * scaleFactor,
                height: pageRect.height * scaleFactor
            )
            
            let renderer = UIGraphicsImageRenderer(size: renderSize)
            let rendered = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: renderSize))
                
                context.cgContext.translateBy(x: 0, y: renderSize.height)
                context.cgContext.scaleBy(x: scaleFactor, y: -scaleFactor)
                
                pdfPage.draw(with: .mediaBox, to: context.cgContext)
            }
            
            return rendered
        }.value
        
        pageImage = image
        isLoading = false
    }
}
