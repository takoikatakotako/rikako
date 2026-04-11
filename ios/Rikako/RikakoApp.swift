//
//  RikakoApp.swift
//  Rikako
//
//  Created by jumpei ono on 2026/03/15.
//

import SwiftUI

@main
struct RikakoApp: App {
    @State private var studyStore = StudyStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(studyStore)
                .preferredColorScheme(.light)
        }
    }
}
