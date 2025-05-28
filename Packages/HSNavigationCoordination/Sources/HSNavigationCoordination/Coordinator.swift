import Foundation
import SwiftUI

// MARK: - Navigation Types

public enum NavigationForwardType {
    case push
    case replaceRoot
    case sheet
    case fullScreenCover
}

public enum NavigationBackType {
    case popTo(AnyRoutable)
    case pop(last: Int)
    case dismissSheet
    case dismissFullScreenCover
}

/// userInitiated means if the the coordinator finish was due to a user interaction, such as a swipe to dismiss or to pop the navigation stack.  Perhaps your code will react differently.
public typealias CoordinatorFinishBlock = (_ userInitiated: Bool, _ result: Any?, _ finishingCoordinator: AnyCoordinator) -> Void
public typealias ViewDefaultFinishBlock = () -> Void

// MARK: - Type-erased Coordinator

public protocol CoordinatorProtocol: AnyObject {
    var identifier: String { get }
    func push<Route: Routable>(_ route: Route, type: NavigationForwardType)
    func goBack(_ type: NavigationBackType)
    func reset()
    
    /// this is used as a callback of CoordinatedView so that it can handle any navigations that weren't triggered in code.
    /// The identifier can be used to give context to a view, while troubleshooting.
    /// if coordinator finish block MUST have the first argument (userInitiated set to true).
    func viewDisappeared(route: AnyRoutable, defaultExit: ViewDefaultFinishBlock?)
}


public struct AnyCoordinator {
    fileprivate let _coordinator: any CoordinatorProtocol
    
    public init<T: CoordinatorProtocol>(_ coordinator: T) {
        self._coordinator = coordinator
    }
    
    var identifier: String { _coordinator.identifier }
    
    func push<Route: Routable>(_ route: Route, type: NavigationForwardType = .push) {
        _coordinator.push(route, type: type)
    }
    
    func goBack(_ type: NavigationBackType = .pop(last: 1)) {
        _coordinator.goBack(type)
    }
    
    func reset() {
        _coordinator.reset()
    }
    
    func viewDisappeared(route: AnyRoutable, defaultExit: ViewDefaultFinishBlock?) {
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
public class SharedNavigationPath {
    
    public private(set) var routes: [AnyRoutable] = []
    
    public var path: NavigationPath {
        didSet {
            let count = path.count
            self.routes = Array(self.routes[0..<count])
            print("Did Set Navigation Path:\n\(self.routes.map { $0.identifier })")
        }
    }
    
    fileprivate init(_ path: NavigationPath = NavigationPath()) {
        self.path = path
    }
    
    public func append(_ routable: any Routable) {
        routes.append(AnyRoutable(routable))
        path.append(routable)
    }
}

@Observable
public class Coordinator<Route: Routable>: CoordinatorProtocol {
    
    // MARK: - Navigation State
    
    private var sharedPath: SharedNavigationPath
    var path: NavigationPath {
        get { sharedPath.path }
        set { sharedPath.path = newValue }
    }
    
    /// mostly for debugging.  If you need to know what routes in the `sharedPath` are managed by this Coordinator.
    public var localStack: [Route] {
        var routes: [Route] = [self.initialRoute]
        routes.append(
            contentsOf: sharedPath.routes.compactMap { $0.typedByRoute(as: Route.self) }
        )
        return routes
    }
    
    /// A Value you provide that uniquely identifies this coordinator.
    public let identifier: String
    
    /// If this were a UINavigationController, this would be your first view controller in the stack.
    public var initialRoute: Route
    public var sheet: Route?
    public var fullscreenCover: Route?
    
    // MARK: - Generic Data Storage
    
    /// you can use a simple dictionary to avoid having to construct your own Coordinator types just to store data.
    public var userData: [String: Any] = [:]
    /// use this to set a defaultFinish value, otherwise nil is passed to the onFinish block.
    public let defaultFinishValueKey: String = "DefaultFinishValueKey"
    
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
    private var onFinish: CoordinatorFinishBlock?
    
    // MARK: - Initialization
    public convenience init(identifier: String, initialRoute: Route, onFinish: CoordinatorFinishBlock? = nil) {
        self.init(
            identifier: identifier,
            initialRoute: initialRoute,
            sharedPath: SharedNavigationPath(NavigationPath()),
            onFinish: onFinish
        )
    }
    
    /// Initializer for child coordinators with shared path reference
    public init(identifier: String, initialRoute: Route, sharedPath: SharedNavigationPath, onFinish: CoordinatorFinishBlock? = nil) {
        
        self.identifier = identifier
        self.sharedPath = sharedPath
        self.onFinish = onFinish
        self.initialRoute = initialRoute
    }
   
    
    // MARK: - Child Coordinator Management
    
    /// To create a standard Coordinator that manages the given `ChildRoute`.  If you need to create custom subclasses, see `buildChildCoordinator(...)`
    public func createChildCoordinator<ChildRoute: Routable>(
        identifier: String,
        initialRoute: ChildRoute,
        navigationForwardType: NavigationForwardType,
        onFinish: @escaping (Bool, Any?) -> Void
    ) -> Coordinator<ChildRoute> {
        
        if let existingAny = childCoordinators[identifier] {
            guard let existing = existingAny.typedByRoute(as: ChildRoute.self) else {
                fatalError("There is a coordinator that exists with this identifier, but a different type!")
            }
            return existing
        }
        
        guard navigationForwardType != .replaceRoot else {
            fatalError("Invalid configuration.  It makes no sense to replace the root view controller with a child view controller.  This could result in a NavigationStack inside a navigation stack.  Behaviour undefined as this hasn't been considered in the technical design.")
        }
        
        let childCoordinator = Coordinator<ChildRoute>(
            identifier: identifier,
            initialRoute: initialRoute,
            sharedPath: navigationForwardType == .push ? sharedPath : .init(NavigationPath()),
            onFinish: { [weak self] userInitiated, anyResult, thisCoordinator in
                onFinish(userInitiated, anyResult)
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
    /// Note as well the parameter navigationForwardType.
    public func buildChildCoordinator<ChildRoute: Routable, CoordinatorType: Coordinator<ChildRoute>>(
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
    
    public func removeChildCoordinator(_ child: AnyCoordinator) {
        childCoordinators[child.identifier] = nil
    }
    
    // MARK: - Finish Methods
    
    public func finish(with result: Any? = nil, userInitiated: Bool = false) {
        print("[\(String(describing: Route.self))] Coordinator finishing with payload: \(String(describing: result))")
        onFinish?(userInitiated, result, AnyCoordinator(self))
    }
    
    // MARK: - Navigation Methods
    
    public func push<T: Routable>(_ route: T, type: NavigationForwardType = .push) {
        
        switch type {
        case .push:
            guard let typedRoute = route as? Route else {
                fatalError("Misuse!")
            }
            print("[\(String(describing: Route.self))] Pushing typed route: \(route)")
            wasProgrammaticallyPopped = false
            sharedPath.append(typedRoute)
        case .replaceRoot:
            guard let typedRoute = route as? Route else {
                fatalError("Misuse!  You should not replace routes of different types.")
            }
            print("[\(String(describing: Route.self))] Replacing Stack to typed route: \(route)")
            wasProgrammaticallyPopped = false
            // sharedPath.removeAll()
            self.initialRoute = typedRoute
            
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
    
    public func goBack(_ type: NavigationBackType = .pop(last: 1)) {
        
        switch type {
        case .pop(let count):
            let actualCount = min(count, localStack.count)
            if actualCount > 0 {
                wasProgrammaticallyPopped = true // sets a flag for viewDisappeared
                path.removeLast(actualCount)
            }
        case .popTo(let toAnyRoute):
            fatalError("Implement me")
            
        case .dismissSheet:
            wasProgrammaticallyPopped = true
            isPresentingSheet = false
            sheet = nil
        case .dismissFullScreenCover:
            wasProgrammaticallyPopped = true // this is necessary
            isPresentingFullscreenCover = false
            fullscreenCover = nil
        }
    }
    
    /// Resets the Coordinator to the state when it began while also 'finishing' as well.  (Notifies and cleans up with the parent).
    /// Typically you'll call this on a child coordinator
    public func reset(finishingWith payload: Any? = nil) {
        reset()
        self.finish(with: payload)
    }
    
    /// Typically you'll only ever call this on a top-level Coordinator.  See `reset(finishingWith: ...)` if that's preferable.
    public func reset() {
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
    public func viewDisappeared(route: AnyRoutable, defaultExit: ViewDefaultFinishBlock?) {
        
        
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
            if isInNavPath {
                print("Disappeared due to something being pushed on top of it.")
            } else if !isInNavPath {
                if typedRoute != self.initialRoute {
                    print("[\(String(describing: Route.self)).\(String(describing: typedRoute))] Route was popped by back/swipe")
                    print("defaultExit will be called.")
                    defaultExit?()
                } else if typedRoute == self.initialRoute && self.isChild {
                    // this means the view disappeared is the first in the stack, thus the stack was automatically popped.
                    print("defaultExit will be called then the onFinish method will be called.")
                    defaultExit?()
                    self.finish(with: self.userData[self.defaultFinishValueKey], userInitiated: true)
                }
            }
        }
        
        wasProgrammaticallyPopped = false
    }
}
