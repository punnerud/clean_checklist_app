//
//  ContentView.swift
//  ShoppingList2
//
//  Created by Morten Punnerud-Engelstad on 30/10/2024.
//

import SwiftUI
import CoreData

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var newItemName = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var headerOffset: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var headerVisible = true
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer: Timer?
    @State private var isEditing = false
    @State private var textSize: Double = 16  // Default text size
    @State private var addToTop: Bool = false // Default to adding at bottom
    @AppStorage("textSize") private var savedTextSize: Double = 16
    @AppStorage("addToTop") private var savedAddToTop: Bool = false
    @State private var showDeleteConfirmation = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.order, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    private func itemExists(_ name: String) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespaces).lowercased()
        return items.contains { item in
            (item.name ?? "").trimmingCharacters(in: .whitespaces).lowercased() == normalizedName
        }
    }

    private func addItem(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty { return }
        
        if !itemExists(trimmedName) {
            withAnimation {
                let newItem = Item(context: viewContext)
                newItem.timestamp = Date()
                newItem.name = trimmedName
                newItem.isCompleted = false
                newItem.quantity = 1
                
                if addToTop {
                    // Shift existing items down
                    for item in items {
                        item.order += 1
                    }
                    newItem.order = 0
                } else {
                    newItem.order = Int32(items.count)
                }

                do {
                    try viewContext.save()
                    newItemName = ""
                } catch {
                    let nsError = error as NSError
                    print("Error saving context: \(nsError), \(nsError.userInfo)")
                }
            }
        } else {
            newItemName = ""
        }
    }

    private func updateQuantity(for item: Item, delta: Int32) {
        withAnimation {
            let newQuantity = item.quantity + delta
            if newQuantity > 0 {
                item.quantity = newQuantity
                try? viewContext.save()
            }
        }
    }

    private func addMultipleItems(_ itemNames: [String]) {
        // Filter out duplicates and empty items
        let newItems = itemNames
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !itemExists($0) }
        
        // Add all new items
        withAnimation {
            for itemName in newItems {
                let newItem = Item(context: viewContext)
                newItem.timestamp = Date()
                newItem.name = itemName
                newItem.isCompleted = false
                newItem.order = Int32(items.count)
                newItem.quantity = 1  // Add this line to set initial quantity
            }
            
            try? viewContext.save()
        }
        
        newItemName = ""
    }

    private func deleteAllItems() {
        withAnimation {
            items.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }

    private func pasteFromClipboard() {
        if let pastedText = UIPasteboard.general.string {
            let items = pastedText
                .split(whereSeparator: { $0.isNewline || $0 == "," })
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            addMultipleItems(items)
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Header View
                VStack(spacing: 0) {
                    HStack {
                        Text("Clean Checklist")
                            .font(.largeTitle)
                            .bold()
                            .onTapGesture {
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)) {
                                    headerOffset = 0
                                    isTextFieldFocused = true
                                }
                            }
                        
                        Spacer()
                        
                        Menu {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete All Items", systemImage: "trash")
                            }
                            
                            Toggle(isOn: $addToTop) {
                                Label("Add New Items to Top", systemImage: "arrow.up")
                            }
                            .onChange(of: addToTop) { newValue in
                                savedAddToTop = newValue
                            }
                            
                            Menu("Text Size") {
                                Button {
                                    textSize = 12
                                    savedTextSize = textSize
                                } label: {
                                    HStack {
                                        Text("Small")
                                        if textSize == 12 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Button {
                                    textSize = 16
                                    savedTextSize = textSize
                                } label: {
                                    HStack {
                                        Text("Medium")
                                        if textSize == 16 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Button {
                                    textSize = 22
                                    savedTextSize = textSize
                                } label: {
                                    HStack {
                                        Text("Large")
                                        if textSize == 22 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Button {
                                    textSize = 30
                                    savedTextSize = textSize
                                } label: {
                                    HStack {
                                        Text("Very Large")
                                        if textSize == 30 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    textSize = 60
                                    savedTextSize = textSize
                                } label: {
                                    HStack {
                                        Text("Very Very Large")
                                        if textSize == 60 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            Button(action: {
                                pasteFromClipboard()
                            }) {
                                Label("Paste Items", systemImage: "doc.on.clipboard")
                            }
                        } label: {
                            Image(systemName: "gear")
                                .imageScale(.large)
                        }
                        .padding(.horizontal, 8)
                        .confirmationDialog(
                            "Delete All Items?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete All", role: .destructive) {
                                deleteAllItems()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This action cannot be undone.")
                        }
                        
                        Button(action: {
                            withAnimation {
                                isEditing.toggle()
                            }
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    HStack {
                        TextField("Add new item", text: $newItemName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onChange(of: newItemName) { newValue in
                                if newValue.contains("\n") || newValue.contains(",") {
                                    let items = newValue
                                        .split(whereSeparator: { $0.isNewline || $0 == "," })
                                        .map(String.init)
                                    addMultipleItems(items)
                                }
                            }
                            .onSubmit {
                                if !newItemName.isEmpty {
                                    addItem(name: newItemName)
                                    isTextFieldFocused = true
                                }
                            }
                        Button(action: { 
                            if !newItemName.isEmpty {
                                addItem(name: newItemName)
                            }
                        }) {
                            Label("Add Item", systemImage: "plus.circle.fill")
                        }
                        .disabled(newItemName.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))
                .offset(y: headerOffset)
                .opacity(1.0 - (abs(headerOffset) / CGFloat(110)))
                .zIndex(1)
                
                // Main List View
                List {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: -geometry.frame(in: .global).minY
                            )
                            .onChange(of: -geometry.frame(in: .global).minY) { newValue in
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)) {
                                    if newValue > -30 {
                                        headerOffset = -110
                                        // Hide keyboard without changing focus
                                        UIApplication.shared.keyWindow?.endEditing(true)
                                    } else if newValue < -80 {
                                        headerOffset = 0
                                    }
                                }
                            }
                    }
                    .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    
                    Color.clear
                        .frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    
                    ForEach(items) { item in
                        HStack(spacing: 0) {
                            HStack {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                
                                if isEditing {
                                    TextField("Item name", text: Binding(
                                        get: { item.name ?? "" },
                                        set: { newValue in
                                            item.name = newValue
                                            try? viewContext.save()
                                        }
                                    ))
                                } else {
                                    Text(item.name ?? "")
                                        .strikethrough(item.isCompleted)
                                        .font(.system(size: textSize))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !isEditing {
                                    toggleItemCompletion(item)
                                }
                            }
                            
                            if !isEditing {
                                HStack(spacing: 15) {
                                    if item.quantity > 1 {
                                        Button {
                                            updateQuantity(for: item, delta: -1)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        
                                        Text("\(item.quantity)")
                                            .frame(minWidth: 30)
                                            .multilineTextAlignment(.center)
                                            .font(.system(size: textSize))
                                    }
                                    
                                    Button {
                                        updateQuantity(for: item, delta: 1)
                                    } label: {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                        .padding(.vertical, 2)  // Add some vertical padding for better tap area
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { _ in
                                    if !isEditing {
                                        toggleItemCompletion(item)
                                    }
                                },
                            including: .subviews
                        )
                        .allowsHitTesting(true)
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)
                    
                    Color.clear
                        .frame(height: UIScreen.main.bounds.height / 2)  // Half screen height padding
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Activate keyboard immediately when app launches
            isTextFieldFocused = true
        }
    }

    private func toggleItemCompletion(_ item: Item) {
        withAnimation {
            item.isCompleted.toggle()
            try? viewContext.save()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
            reorderItems()
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var revisedItems: [Item] = items.map { $0 }
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.order = Int32(index)
        }
        
        try? viewContext.save()
    }
    
    private func reorderItems() {
        for (index, item) in items.enumerated() {
            item.order = Int32(index)
        }
        try? viewContext.save()
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
