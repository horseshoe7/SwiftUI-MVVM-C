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
            CoordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(coordinator.initialRoute)
            ) {
                coordinator.initialRoute.makeView(with: coordinator, presentationStyle: .push)
            }
            .navigationDestination(for: Route.self) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .push)
                }
            }
            .sheet(item: $coordinator.sheet) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .sheet)
                }
            }
            .fullScreenCover(item: $coordinator.fullscreenCover) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .fullscreenCover)
                }
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
        
        CoordinatedView(
            coordinator: AnyCoordinator(coordinator),
            route: AnyRoutable(coordinator.initialRoute)
        ) {
            coordinator.initialRoute.makeView(with: coordinator, presentationStyle: .push)
        }
            .navigationDestination(for: Route.self) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .push)
                }
            }
            .sheet(item: $coordinator.sheet) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .sheet)
                }
            }
            .fullScreenCover(item: $coordinator.fullscreenCover) { route in
                CoordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(route)
                ) {
                    route.makeView(with: coordinator, presentationStyle: .fullscreenCover)
                }
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
    @State private var defaultExit: (() -> Void) = {}
    
    public init(
        coordinator: AnyCoordinator,
        defaultExit: (() -> Void)? = nil,
        route: AnyRoutable,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.coordinator = coordinator
        self.content = content
        self.route = route
    }
    
    public var body: some View {
        content()
            .environment(\.coordinator, coordinator)
            .onDisappear {
                coordinator.viewDisappeared(route: route, defaultExit: defaultExit)
            }
            .onPreferenceChange(
                DefaultExitPreference.self,
                perform: {
                    self.defaultExit = $0.action
                }
            )
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

public extension View {
    func onDefaultExit(_ action: @escaping () -> Void) -> some View {
        self
            .modifier(DefaultExitBehaviourModifier(defaultExitAction: .init(action: action)))
    }
}

struct ActionContainer: Equatable {
    
    nonisolated(unsafe) static let emptyAction = ActionContainer(action: {})
    let id = UUID()
    
    let action: () -> Void
    
    static func == (lhs: ActionContainer, rhs: ActionContainer) -> Bool {
        return lhs.id == rhs.id // no two blocks are identical.  Any time you set one, it's "new"
    }
}


struct DefaultExitBehaviourModifier: ViewModifier {
    
    let defaultExitAction: ActionContainer

    func body(content: Content) -> some View {
        content
            .preference(
                key: DefaultExitPreference.self,
                value: defaultExitAction
            )
    }
}

struct DefaultExitPreference: PreferenceKey {
    static func reduce(value: inout ActionContainer, nextValue: () -> ActionContainer) {
        value = nextValue()
    }
    
    nonisolated(unsafe) static let defaultValue: ActionContainer = .emptyAction
}
