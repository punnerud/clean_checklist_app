//
//  ShoppingList2App.swift
//  ShoppingList2
//
//  Created by Morten Punnerud-Engelstad on 30/10/2024.
//

import SwiftUI

@main
struct ShoppingList2App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
