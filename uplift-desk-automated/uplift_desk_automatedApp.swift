//
//  uplift_desk_automatedApp.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//

import SwiftUI

@main
struct uplift_desk_automatedApp: App {
    @AppStorage("automationPaused") private var isPaused = false

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: isPaused
                  ? "pause.circle.fill"
                  : "rectangle.and.arrow.up.right.and.arrow.down.left")
        }
        .menuBarExtraStyle(.window)
    }
}
