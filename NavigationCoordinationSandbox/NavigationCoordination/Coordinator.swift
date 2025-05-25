import Foundation
import SwiftUI

// MARK: - Navigation Types

enum NavigationType {
    case push
    case sheet
    case fullScreenCover
}

enum NavigationPopType {
    case pop(last: Int)
    case sheet
    case fullScreenCover
}


// MARK: - Type-erased Coordinator

protocol CoordinatorProtocol: AnyObject {
    var identifier: String { get }
    func push<Route: Routable>(_ route: Route, type: NavigationType)
    func pop(_ type: NavigationPopType)
    func reset()
    
    /// this is used as a callback of CoordinatedView so that it can handle any navigations that weren't triggered in code.
    /// The identifier can be used to give context to a view, while troubleshooting.
    func viewDisappeared(route: AnyRoutable, defaultExit: (() -> Void)?)
}


struct AnyCoordinator {
    fileprivate let _coordinator: any CoordinatorProtocol
    
    init<T: CoordinatorProtocol>(_ coordinator: T) {
        self._coordinator = coordinator
    }
    
    var identifier: String { _coordinator.identifier }
    
    func push<Route: Routable>(_ route: Route, type: NavigationType = .push) {
        _coordinator.push(route, type: type)
    }
    
    func pop(_ type: NavigationPopType = .pop(last: 1)) {
        _coordinator.pop(type)
    }
    
    func reset() {
        _coordinator.reset()
    }
    
    func viewDisappeared(route: AnyRoutable, defaultExit: (() -> Void)?) {
        _coordinator.viewDisappeared(route: route, defaultExit: defaultExit)
    }
    
    func typedByRoute<T: Routable>(as type: T.Type) -> Coordinator<T>? {
        return _coordinator as? Coordinator<T>
    }
    
    func typedCoordinator<T: CoordinatorProtocol>(as type: T.Type) -> T? {
        return _coordinator as? T
    }
}

// MARK: - Coordinator

/// A type that manages both the type erased NavigationPath (yet does have type when used with .navigationDestination)
/// and tracks a list of `AnyRoutable` that is used by the `Coordinator`.
@Observable
class SharedNavigationPath {
    
    private(set) var routes: [AnyRoutable] = []
    
    var path: NavigationPath {
        didSet {
            let count = path.count
            self.routes = Array(self.routes[0..<count])
            print("Did Set Navigation Path:\n\(self.routes.map { $0.identifier })")
        }
    }
    
    fileprivate init(_ path: NavigationPath = NavigationPath()) {
        self.path = path
    }
    
    func append(_ routable: any Routable) {
        routes.append(AnyRoutable(routable))
        path.append(routable)
    }
}

@Observable
class Coordinator<Route: Routable>: CoordinatorProtocol {
    
    // MARK: - Navigation State
    
    private var sharedPath: SharedNavigationPath
    var path: NavigationPath {
        get { sharedPath.path }
        set { sharedPath.path = newValue }
    }
    
    /// mostly for debugging.  If you need to know what routes in the `sharedPath` are managed by this Coordinator.
    var localStack: [Route] {
        var routes: [Route] = [self.initialRoute]
        routes.append(
            contentsOf: sharedPath.routes.compactMap { $0.typedByRoute(as: Route.self) }
        )
        return routes
    }
    
    /// A Value you provide that uniquely identifies this coordinator.
    let identifier: String
    
    /// If this were a UINavigationController, this would be your first view controller in the stack.
    let initialRoute: Route
    var sheet: Route?
    var fullscreenCover: Route?
    
    // MARK: - Child Coordinator Management
    
    private var childCoordinators: [String: AnyCoordinator] = [:]
    
    // MARK: - Navigation Tracking
    
    // because viewDisappeared will be called some time after you might pop things.
    
    /// This is taken to mean "pop" or "dismissed" depending on the context.
    private var wasProgrammaticallyPopped = false
    /// this tracks if you've presented it, but sheet could have been modified by someone else (back to nil).  Used in the viewDisappeared(...) method
    private var isPresentingSheet = false
    /// this tracks if you've presented it, but fullscreen cover could have been modified by someone else (back to nil).  Used in the viewDisappeared(...) method
    private var isPresentingFullscreenCover = false
    /// special case where we won't ever trigger defaultExit on a parent coordinator as this represents the root of a stack (i.e. cannot exit)
    private var isChild = false
    
    
    // MARK: - Exit Callbacks
    
    /// provides the return type of the coordinator, and the type-erased coordinator that just finished. (i.e. so you can remove it)
    private var onFinish: ((Any?, AnyCoordinator) -> Void)?
    
    // MARK: - Initialization
    convenience init(identifier: String, initialRoute: Route, onFinish: ((Any?, AnyCoordinator) -> Void)? = nil) {
        self.init(
            identifier: identifier,
            initialRoute: initialRoute,
            sharedPath: SharedNavigationPath(NavigationPath()),
            onFinish: onFinish
        )
    }
    
    /// Initializer for child coordinators with shared path reference
    init(identifier: String, initialRoute: Route, sharedPath: SharedNavigationPath, onFinish: ((Any?, AnyCoordinator) -> Void)? = nil) {
        
        self.identifier = identifier
        self.sharedPath = sharedPath
        self.onFinish = onFinish
        self.initialRoute = initialRoute
    }
   
    
    // MARK: - Child Coordinator Management
    
    /// To create a standard Coordinator that manages the given `ChildRoute`.  If you need to create custom subclasses, see `buildChildCoordinator(...)`
    func createChildCoordinator<ChildRoute: Routable>(
        identifier: String,
        initialRoute: ChildRoute,
        onFinish: @escaping (Any?) -> Void
    ) -> Coordinator<ChildRoute> {
        
        if let existingAny = childCoordinators[identifier] {
            guard let existing = existingAny.typedByRoute(as: ChildRoute.self) else {
                fatalError("There is a coordinator that exists with this identifier, but a different type!")
            }
            return existing
        }
        
        let childCoordinator = Coordinator<ChildRoute>(
            identifier: identifier,
            initialRoute: initialRoute,
            sharedPath: sharedPath,
            onFinish: { [weak self] anyResult, thisCoordinator in
                onFinish(anyResult)
                // Remove the child coordinator when it finishes
                self?.removeChildCoordinator(thisCoordinator)
            }
        )
        childCoordinator.isChild = true
        
        let anyChild = AnyCoordinator(childCoordinator)
        childCoordinators[identifier] = anyChild
        
        return childCoordinator
    }
    
    /// if you build your own, be sure it removes the child from the parent.  See `createChildCoordinator(...)`'s onFinish implementation for an example.
    func buildChildCoordinator<ChildRoute: Routable, CoordinatorType: Coordinator<ChildRoute>>(
        identifier: String,
        initialRoute: ChildRoute,
        builder: (Coordinator<Route>, SharedNavigationPath) -> CoordinatorType
    ) -> CoordinatorType {
        
        if let existingAny = childCoordinators[identifier] {
            guard let existing = existingAny.typedCoordinator(as: CoordinatorType.self) else {
                fatalError("There is a coordinator that exists with this identifier, but a different type!")
            }
            return existing
        }
        
        let childCoordinator = builder(self, sharedPath)
        childCoordinator.isChild = true
        
        let anyChild = AnyCoordinator(childCoordinator)
        childCoordinators[identifier] = anyChild
        
        return childCoordinator
    }
    
    private func removeChildCoordinator(_ child: AnyCoordinator) {
        childCoordinators[child.identifier] = nil
    }
    
    // MARK: - Finish Methods
    
    func finish(with payload: Any? = nil) {
        print("[\(String(describing: Route.self))] Coordinator finishing with payload: \(String(describing: payload))")
        onFinish?(payload, AnyCoordinator(self))
    }
    
    // MARK: - Navigation Methods
    
    func push<T: Routable>(_ route: T, type: NavigationType = .push) {
        
        switch type {
        case .push:
            guard let typedRoute = route as? Route else {
                fatalError("Misuse!")
            }
            print("[\(String(describing: Route.self))] Pushing typed route: \(route)")
            wasProgrammaticallyPopped = false
            sharedPath.append(typedRoute)
            
        case .sheet:
            guard let typedRoute = route as? Route else {
                fatalError("Warning: Cannot present sheet with cross-type route from typed coordinator")
            }
            print("[\(String(describing: Route.self))] Presenting Sheet: \(typedRoute)")
            isPresentingSheet = true
            sheet = typedRoute
            
        case .fullScreenCover:
            guard let typedRoute = route as? Route else {
                fatalError("Warning: Cannot present fullScreenCover with cross-type route from typed coordinator")
            }
            print("[\(String(describing: Route.self))] Presenting FullScreenCover: \(typedRoute)")
            isPresentingFullscreenCover = true
            fullscreenCover = typedRoute
        }
    }
    
    func pop(_ type: NavigationPopType = .pop(last: 1)) {
        
        switch type {
        case .pop(let count):
            let actualCount = min(count, localStack.count)
            if actualCount > 0 {
                wasProgrammaticallyPopped = true // sets a flag for viewDisappeared
                path.removeLast(actualCount)
            }
        case .sheet:
            wasProgrammaticallyPopped = true
            isPresentingSheet = false
            sheet = nil
        case .fullScreenCover:
            wasProgrammaticallyPopped = true // this is necessary
            isPresentingFullscreenCover = false
            fullscreenCover = nil
        }
    }
    
    /// Resets the Coordinator to the state when it began while also 'finishing' as well.  (Notifies and cleans up with the parent).
    /// Typically you'll call this on a child coordinator
    func reset(finishingWith payload: Any? = nil) {
        reset()
        self.finish(with: payload)
    }
    
    /// Typically you'll only ever call this on a top-level Coordinator.  See `reset(finishingWith: ...)` if that's preferable.
    func reset() {
        print("[\(String(describing: Route.self))] Resetting coordinator")
        
        // Clean up child coordinators
        childCoordinators.removeAll()
        
        // Reset navigation state
        if !localStack.isEmpty {
            
            // now iterate from the back, get the index of when the route does not cast to this Route
            var numToRemove: Int? = nil
            for (index, anyRoute) in self.sharedPath.routes.reversed().enumerated() {
                if anyRoute.typedByRoute(as: Route.self) == nil {
                    numToRemove = index + (self.isChild ? 1 : 0)
                    break
                }
            }
            if let numToRemove {
                path.removeLast(numToRemove)
            } else {
                path.removeLast(path.count)
            }
        }
        
        sheet = nil
        fullscreenCover = nil
        wasProgrammaticallyPopped = true
    }
    
    /// we require this function to do appropriate cleanup on a screen being 'done' if the user didn't perform a task that led to an explicit 'pop' action.
    /// You should never invoke this yourself; it is used by the `coordinatedView(...)` modifier.
    func viewDisappeared(route: AnyRoutable, defaultExit: (() -> Void)?) {
        
        
        /*
         So, viewDisappeared can be tricky, because it's literally when it disappears.
         Situations where a given view disappears:
         - A) A new view is pushed onto the stack (over top of it)
         - B) the view itself is popped from the stack
         - C) the stack is popped to root, and the view was in the collection of views that were popped.
         - D) a new view is presented over top
         - E) the view itself was the presented view.
         */
        
        // you can see if this route is in the local stack or what's going on.
        // let typedRoute = route.typedByRoute(as: Route.self)
        
        print("[\(String(describing: Route.self))] View with Route `\(route.identifier)` disappeared. Programmatically: \(wasProgrammaticallyPopped)")
        
        if isPresentingSheet && sheet == nil {
            // then it was dismissed through user interaction and not programmatically
            isPresentingSheet = false
            print("defaultExit will be called in response to sheet dismissal.")
            defaultExit?()
            return
        }
        
        if isPresentingFullscreenCover && fullscreenCover == nil {
            // then it was dismissed through user interaction and not programmatically
            isPresentingFullscreenCover = false
            print("defaultExit will be called in response to fullscreen cover dismissal.")
            defaultExit?()
            return
        }
        
        guard !wasProgrammaticallyPopped else {
            // nothing to do because we programmatically changed things, thus exits were properly invoked.
            wasProgrammaticallyPopped = false
            return
        }

        
        if let typedRoute = route.typedByRoute(as: Route.self) {
             
            let isInNavPath = sharedPath.routes.contains(where: { $0.identifier == typedRoute.identifier })
            if isInNavPath || (typedRoute == self.initialRoute) {
                print("Disappeared due to something being pushed on top of it.")
            } else if !isInNavPath && (typedRoute != self.initialRoute || (typedRoute == self.initialRoute && self.isChild)) {
                print("[\(String(describing: Route.self)).\(String(describing: typedRoute))] Route was popped by back/swipe")
                print("defaultExit will be called.")
                defaultExit?()
            }
        }
        
        wasProgrammaticallyPopped = false
    }
}
