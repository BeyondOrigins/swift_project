//
//  DjVuPageView.swift
//  BookWorm
//
//  Created by beyondorigins on 22.03.2026.
//

import SwiftUI

struct DjVuPageView: View {
    let book: Book
    let pageIndex: Int
    
    @State private var pageImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Group {
            if let image = pageImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = max(1.0, min(value.magnification, 5.0))
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation { scale = scale > 1.0 ? 1.0 : 2.5 }
                    }
            } else if isLoading {
                ProgressView("Rendering page...")
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                Text("Could not render page")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .task(id: pageIndex) {
            await loadPage()
        }
    }
    
    private func loadPage() async {
        isLoading = true
        
        guard let path = book.localFilePath else {
            isLoading = false
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        let image = await Task.detached(priority: .userInitiated) {
            await BookParserService.shared.getDjVuPageImage(
                fileURL: url,
                page: pageIndex,
                dpi: 300
            )
        }.value
        
        pageImage = image
        isLoading = false
    }
}
