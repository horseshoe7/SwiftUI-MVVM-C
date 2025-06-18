//
//  NavigationCoordinationSandboxApp.swift
//  NavigationCoordinationSandbox
//
//  Created by Stephen OConnor on 23.05.25.
//

import SwiftUI
import HSNavigationCoordination

@main
struct NavigationCoordinationSandboxApp: App {
    
    // we set up a top-level coordinator, indicate we want to start with the given route, and this coordinator will manage a NavigationStack
    @State var coordinator: Coordinator<MainRoute> = .init(
        identifier: "AppCoordinator",
        initialRoute: MainRoute.home,
        presentationStyle: .push
    )
    
    var body: some Scene {
        WindowGroup {
            CoordinatorStack<MainRoute>()
                .environment(coordinator)
        }
    }
}
