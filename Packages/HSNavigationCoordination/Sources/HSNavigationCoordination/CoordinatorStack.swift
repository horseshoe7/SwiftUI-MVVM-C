import Foundation
import SwiftUI

// MARK: - Coordinator Stack

/// This is a View you would use to create a NavigationStack with views built by a Coordinator
public struct CoordinatorStack<Route: Routable>: View {
    
    @Environment(Coordinator<Route>.self) var coordinator
    
    public init() {
        
    }
    
    public var body: some View {
        @Bindable var coordinator = coordinator
        
        NavigationStack(path: $coordinator.path) {
            coordinator.initialRoute.makeView(with: coordinator, presentationStyle: .push)
            .navigationDestination(for: Route.self) { route in
                route.makeView(with: coordinator, presentationStyle: .push)
            }
            .sheet(item: $coordinator.sheet) { route in
                route.makeView(with: coordinator, presentationStyle: .sheet)
            }
            .fullScreenCover(item: $coordinator.fullscreenCover) { route in
                route.makeView(with: coordinator, presentationStyle: .fullscreenCover)
            }
        }
    }
}

/// This is the type you would use if you're pushing views managed by a coordinator onto an existing NavigationStack
public struct ChildCoordinatorStack<Route: Routable>: View {
    
    @Environment(Coordinator<Route>.self) var coordinator
    
    public init() {
        
    }
    
    public var body: some View {
        @Bindable var coordinator = coordinator
        
        coordinator.initialRoute.makeView(with: coordinator, presentationStyle: .push)
            .navigationDestination(for: Route.self) { route in
                route.makeView(with: coordinator, presentationStyle: .push)
            }
            .sheet(item: $coordinator.sheet) { route in
                route.makeView(with: coordinator, presentationStyle: .sheet)
            }
            .fullScreenCover(item: $coordinator.fullscreenCover) { route in
                route.makeView(with: coordinator, presentationStyle: .fullscreenCover)
            }
    }
}


// MARK: - Environment Key

private struct CoordinatorEnvironmentKey: EnvironmentKey {
    // TODO: Deal with Concurrency
    nonisolated(unsafe) static let defaultValue: AnyCoordinator? = nil
}

public extension EnvironmentValues {
    var coordinator: AnyCoordinator? {
        get { self[CoordinatorEnvironmentKey.self] }
        set { self[CoordinatorEnvironmentKey.self] = newValue }
    }
}

// MARK: - Coordinated View Wrapper

public struct CoordinatedView<Content: View>: View {
    private let coordinator: AnyCoordinator
    private let content: () -> Content
    private let route: AnyRoutable
    private let defaultExit: (() -> Void)?
    
    public init(
        coordinator: AnyCoordinator,
        defaultExit: (() -> Void)? = nil,
        route: AnyRoutable,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.coordinator = coordinator
        self.content = content
        self.defaultExit = defaultExit
        self.route = route
    }
    
    public var body: some View {
        content()
            .environment(\.coordinator, coordinator)
            .onDisappear {
                coordinator.viewDisappeared(route: route, defaultExit: defaultExit)
            }
    }
}


// MARK: - Convenience Extensions

public extension View {
    func coordinatedView(
        coordinator: AnyCoordinator,
        route: AnyRoutable,
        defaultExit: (() -> Void)? = nil
    ) -> some View {
        CoordinatedView(coordinator: coordinator, defaultExit: defaultExit, route: route) {
            self
        }
    }
}
