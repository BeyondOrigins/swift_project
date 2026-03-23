import SwiftUI
import SwiftData

struct NodeGraphView: View {
    let note: BookNote
    @Bindable var viewModel: NotesViewModel
    let context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var nodes: [NoteNode] = []
    @State private var selectedNode: NoteNode?
    @State private var connectingFrom: NoteNode?
    @State private var showNodeEditor = false
    @State private var editingNode: NoteNode?
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastDragOffset: CGSize = .zero
    @State private var showConnections = false
    @State private var draggingNode: NoteNode?
    
    // Temporary connection line endpoint
    @State private var connectionEndPoint: CGPoint?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedNode = nil
                        connectingFrom = nil
                        connectionEndPoint = nil
                    }
                
                gridPattern
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                canvasOffset = CGSize(
                                    width: lastDragOffset.width + value.translation.width,
                                    height: lastDragOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastDragOffset = canvasOffset
                            }
                    )
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                canvasScale = max(0.3, min(value.magnification, 3.0))
                            }
                    )
                    .allowsHitTesting(draggingNode == nil)
                
                // Canvas
                ZStack {
                    // Connection lines
                    ForEach(nodes) { node in
                        ForEach(node.connectedNodeIDs, id: \.self) { targetID in
                            if let target = nodes.first(where: { $0.id == targetID }),
                               node.id.uuidString < targetID.uuidString {
                                ConnectionLine(
                                    from: CGPoint(x: node.positionX, y: node.positionY),
                                    to: CGPoint(x: target.positionX, y: target.positionY)
                                )
                            }
                        }
                    }
                    
                    if let from = connectingFrom, let endPoint = connectionEndPoint {
                        ConnectionLine(
                            from: CGPoint(x: from.positionX, y: from.positionY),
                            to: endPoint,
                            isDashed: true
                        )
                    }
                    
                    // Nodes
                    ForEach(nodes) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            isConnecting: connectingFrom?.id == node.id
                        )
                        .position(x: node.positionX, y: node.positionY)
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    draggingNode = node
                                    if connectingFrom != nil {
                                        connectionEndPoint = value.location
                                    } else {
                                        if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                                            nodes[idx].positionX = value.location.x
                                            nodes[idx].positionY = value.location.y
                                        }
                                    }
                                }
                                .onEnded { value in
                                    draggingNode = nil
                                    if let from = connectingFrom {
                                        if let target = findNode(near: value.location), target.id != from.id {
                                            viewModel.connectNodes(from, to: target, context: context)
                                            refreshNodes()
                                        }
                                        connectingFrom = nil
                                        connectionEndPoint = nil
                                    } else {
                                        viewModel.updateNodePosition(
                                            node,
                                            x: value.location.x,
                                            y: value.location.y,
                                            context: context
                                        )
                                    }
                                }
                        )
                        .onTapGesture {
                            if let from = connectingFrom {
                                if from.id != node.id {
                                    viewModel.connectNodes(from, to: node, context: context)
                                    refreshNodes()
                                }
                                connectingFrom = nil
                                connectionEndPoint = nil
                            } else {
                                selectedNode = node
                            }
                        }
                        .onLongPressGesture {
                            editingNode = node
                            showNodeEditor = true
                        }
                    }
                }
                .offset(canvasOffset)
                .scaleEffect(canvasScale)
                
                
                
                VStack {
                    Spacer()
                    bottomToolbar
                }
            }
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            addNodeAtCenter()
                        } label: {
                            Label("Add node", systemImage: "plus.circle")
                        }
                        
                        if let node = selectedNode {
                            Button {
                                connectingFrom = node
                            } label: {
                                Label("Connect from selected", systemImage: "link")
                            }
                            
                            Button(role: .destructive) {
                                viewModel.deleteNode(node, allNodes: nodes, context: context)
                                selectedNode = nil
                                refreshNodes()
                            } label: {
                                Label("Delete node", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingNode) { node in
                NodeEditorSheet(node: node, context: context) {
                    refreshNodes()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showConnections) {
                if let node = selectedNode {
                    ConnectionsListSheet(
                        node: node,
                        allNodes: nodes,
                        onDisconnect: { targetNode in
                            viewModel.disconnectNodes(node, from: targetNode, context: context)
                            refreshNodes()
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .onAppear {
                refreshNodes()
            }
        }
    }
    
    // MARK: - Grid Pattern
    
    private var gridPattern: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            let dotSize: CGFloat = 2
            
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.gray.opacity(0.15))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            Button { addNodeAtCenter() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
            }
            .tint(.indigo)
            
            Divider().frame(height: 28)
                .opacity(selectedNode != nil ? 1 : 0)
            
            Button { if let s = selectedNode { connectingFrom = s } } label: {
                Image(systemName: "link")
                    .font(.system(size: 20))
            }
            .tint(.purple)
            .opacity(selectedNode != nil ? 1 : 0)
            .disabled(selectedNode == nil)
            
            Button { showConnections = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 20))
                    if let count = selectedNode?.connectedNodeIDs.count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .tint(.orange)
            .opacity(selectedNode != nil ? 1 : 0)
            .disabled(selectedNode == nil || (selectedNode?.connectedNodeIDs.isEmpty ?? true))
            
            Button { if let s = selectedNode { editingNode = s } } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 20))
            }
            .tint(.blue)
            .opacity(selectedNode != nil ? 1 : 0)
            .disabled(selectedNode == nil)
            
            Button {
                if let node = selectedNode {
                    viewModel.deleteNode(node, allNodes: nodes, context: context)
                    selectedNode = nil
                    refreshNodes()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20))
            }
            .tint(.red)
            .opacity(selectedNode != nil ? 1 : 0)
            .disabled(selectedNode == nil)
            
            if connectingFrom != nil {
                Button {
                    connectingFrom = nil
                    connectionEndPoint = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                }
                .tint(.red)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    withAnimation { canvasScale = max(0.3, canvasScale - 0.2) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text("\(Int(canvasScale * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 38, alignment: .center)
                    .foregroundStyle(.secondary)
                
                Button {
                    withAnimation { canvasScale = min(3.0, canvasScale + 0.2) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5).opacity(0.6))
            .clipShape(Capsule())
        }
        .animation(.easeInOut(duration: 0.15), value: selectedNode?.id)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Helpers
    
    private func addNodeAtCenter() {
        let centerX = UIScreen.main.bounds.width / 2 - canvasOffset.width
        let centerY = UIScreen.main.bounds.height / 2 - canvasOffset.height
        let offset = CGFloat(nodes.count) * 20
        
        let node = viewModel.addNode(
            to: note,
            label: "New Node",
            x: centerX + offset,
            y: centerY + offset,
            context: context
        )
        nodes.append(node)
        selectedNode = node
    }
    
    private func refreshNodes() {
        nodes = note.nodes ?? []
    }
    
    private func findNode(near point: CGPoint, threshold: CGFloat = 60) -> NoteNode? {
        nodes.first { node in
            let dx = node.positionX - Double(point.x)
            let dy = node.positionY - Double(point.y)
            return sqrt(dx * dx + dy * dy) < Double(threshold)
        }
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: NoteNode
    let isSelected: Bool
    let isConnecting: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(node.label)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            if !node.content.isEmpty {
                Text(node.content)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 80, maxWidth: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: node.colorHex)?.opacity(0.15) ?? Color.purple.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.indigo :
                    isConnecting ? Color.orange :
                    (Color(hex: node.colorHex) ?? .purple).opacity(0.5),
                    lineWidth: isSelected || isConnecting ? 2 : 1
                )
        )
        .shadow(color: isSelected ? .indigo.opacity(0.3) : .clear, radius: 6)
    }
}

// MARK: - Connection Line

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    var isDashed: Bool = false
    
    var body: some View {
        Path { path in
            path.move(to: from)
            
            // Curved bezier line
            let midX = (from.x + to.x) / 2
            let midY = (from.y + to.y) / 2
            let controlOffset: CGFloat = 40
            
            let control1 = CGPoint(x: midX - controlOffset, y: from.y)
            let control2 = CGPoint(x: midX + controlOffset, y: to.y)
            
            path.addCurve(to: to, control1: control1, control2: control2)
        }
        .stroke(
            isDashed ? Color.orange : Color.purple.opacity(0.5),
            style: StrokeStyle(
                lineWidth: isDashed ? 1.5 : 1,
                lineCap: .round,
                dash: isDashed ? [6, 4] : []
            )
        )
    }
}

// MARK: - Node Editor Sheet

struct NodeEditorSheet: View {
    let node: NoteNode
    let context: ModelContext
    let onSave: () -> Void
    
    @State private var label: String
    @State private var content: String
    @State private var colorHex: String
    @Environment(\.dismiss) private var dismiss
    
    private let colors = [
        "#8B5CF6", "#6366F1", "#3B82F6", "#06B6D4",
        "#10B981", "#F59E0B", "#EF4444", "#EC4899"
    ]
    
    init(node: NoteNode, context: ModelContext, onSave: @escaping () -> Void) {
        self.node = node
        self.context = context
        self.onSave = onSave
        self._label = State(initialValue: node.label)
        self._content = State(initialValue: node.content)
        self._colorHex = State(initialValue: node.colorHex)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $label)
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 80)
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(colors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture { colorHex = hex }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        node.label = label
                        node.content = content
                        node.colorHex = colorHex
                        try? context.save()
                        onSave()
                        dismiss()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }
}

struct ConnectionsListSheet: View {
    let node: NoteNode
    let allNodes: [NoteNode]
    let onDisconnect: (NoteNode) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var connectedNodes: [NoteNode] {
        allNodes.filter { node.connectedNodeIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if connectedNodes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("No connections")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(connectedNodes) { target in
                            HStack {
                                Circle()
                                    .fill(Color(hex: target.colorHex) ?? .purple)
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.label)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if !target.content.isEmpty {
                                        Text(target.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    onDisconnect(target)
                                    if connectedNodes.count <= 1 {
                                        dismiss()
                                    }
                                } label: {
                                    Image(systemName: "link.badge.plus")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.red, .red)
                                        .rotationEffect(.degrees(45))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Connections from \"\(node.label)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
