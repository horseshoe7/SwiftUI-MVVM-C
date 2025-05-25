//
//  NavigationCoordinationSandboxApp.swift
//  NavigationCoordinationSandbox
//
//  Created by Stephen OConnor on 23.05.25.
//

import SwiftUI

@main
struct NavigationCoordinationSandboxApp: App {
    
    @State var coordinator: Coordinator<MainRoute> = .init(identifier: "AppCoordinator", initialRoute: MainRoute.home)
    
    var body: some Scene {
        WindowGroup {
            CoordinatorStack<MainRoute>()
                .environment(coordinator)
        }
    }
}
