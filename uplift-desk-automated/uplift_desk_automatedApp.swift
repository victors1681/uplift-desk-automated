//
//  uplift_desk_automatedApp.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//

import SwiftUI

@main
struct uplift_desk_automatedApp: App {
    var body: some Scene {
        MenuBarExtra("Uplift Desk", systemImage: "rectangle.and.arrow.up.right.and.arrow.down.left") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
