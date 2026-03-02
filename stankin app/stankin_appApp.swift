//
//  stankin_appApp.swift
//  stankin app
//
//  Created by Дмитрий Нилов on 01.03.2026.
//

import SwiftUI
import UIKit

@main
struct stankin_appApp: App {
    init() {
        UIScrollView.appearance().scrollsToTop = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
