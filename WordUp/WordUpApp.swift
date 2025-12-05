//
//  WordUpApp.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import SwiftUI

@main
struct WordUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
