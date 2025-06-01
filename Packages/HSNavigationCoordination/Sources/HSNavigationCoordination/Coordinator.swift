import Foundation
import SwiftUI

// MARK: - Navigation Types

public enum NavigationPresentationType {
    case push
    case sheet
    case fullScreenCover
    case replaceRoot
}

public enum NavigationBackType {
    /// in the case of a child coordinator, it will pop to the screen that pushed it, removing the child.  In the case of a parent, it will pop to root.  Provide an override return value, otherwise the coordinator's .defaultFinishValue in the userData will be used.
    case unwindToStart(finishValue: Any?)
    /// needs to be the same Route type as its coordinator.
    case popStackTo(AnyRoutable)
    /// this will only pop within the context of the current coordinator.  If you provide a value for `last` larger than the items on the localStack, it will take you to the initial screen in THIS coordinator, but no futher.  Otherwise consider `popToStart(finishValue: )`
    case popStack(last: Int)
    
    /// Note: This isn't for the child to use to dismiss itself from its parent.  This is how a parent can dismiss its sheet.  If you want to dismiss a child coordinator that's been presented as a sheet, pass a value of `unwindToStart(finishValue:)`
    case dismissSheet
    /// Note: This isn't for the child to use to dismiss itself from its parent.  This is how a parent can dismiss its fullscreenCover.  If you want to dismiss a child coordinator that's been presented as a fullscreenCover, pass a value of `unwindToStart(finishValue:)`
    case dismissFullScreenCover
}

/// userInitiated means if the the coordinator finish was due to a user interaction, such as a swipe to dismiss or to pop the navigation stack.  Perhaps your code will react differently.
public typealias CoordinatorFinishBlock = (_ userInitiated: Bool, _ result: Any?, _ finishingCoordinator: AnyCoordinator) -> Void
public typealias ViewDefaultFinishBlock = () -> Void

// MARK: - Type-erased Coordinator

public protocol CoordinatorProtocol: AnyObject {
    /// required for subsequent retrieval
    var identifier: String { get }
    /// if this coordinator is not a child coordinator, this will be nil. Otherwise, the parent will have to make a view for a route, and if that builder creates a child coordinator, you will provide the route in the "parent's Route type", and the child "branches" from that route.  Said another way, the parent's route that spawns the child coordinator.
    var branchedFrom: AnyRoutable? { get }
    
    /// basically to present something.
    func show<Route: Routable>(_ route: Route, presentationStyle: NavigationPresentationType)
    /// to go back
    func goBack(_ type: NavigationBackType)
    
}

/// used internally by the module.
protocol _CoordinatorProtocol: CoordinatorProtocol {
    /// used internally
    var notifyUserInteractiveFinish: Bool { get set }
    
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
    
    var branchedFrom: AnyRoutable? { _coordinator.branchedFrom }
    
    func show<Route: Routable>(_ route: Route, presentationStyle: NavigationPresentationType = .push) {
        _coordinator.show(route, presentationStyle: presentationStyle)
    }
    
    func goBack(_ type: NavigationBackType = .popStack(last: 1)) {
        _coordinator.goBack(type)
    }
    
    func typedByRoute<T: Routable>(as type: T.Type) -> Coordinator<T>? {
        return _coordinator as? Coordinator<T>
    }
    
    func typedCoordinator<T: CoordinatorProtocol>(as type: T.Type) -> T? {
        return _coordinator as? T
    }
}

extension AnyCoordinator {
    func viewDisappeared(route: AnyRoutable, defaultExit: ViewDefaultFinishBlock?) {
        if let coordinator = _coordinator as? _CoordinatorProtocol {
            coordinator.viewDisappeared(route: route, defaultExit: defaultExit)
        } else {
            fatalError("this doesn't work")
        }
    }
    
    var notifyUserInteractiveFinish: Bool {
        get {
            if let coordinator = _coordinator as? _CoordinatorProtocol {
                return coordinator.notifyUserInteractiveFinish
            }
            return false
        }
        set {
            if let coordinator = _coordinator as? _CoordinatorProtocol {
                coordinator.notifyUserInteractiveFinish = newValue
            } else {
                print("Cannot set notifyUserInteractiveFinish")
            }
            
        }
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
        
        // in the even this is a child on the same NavigationStack as its parent.
        if let branchedFrom {
            if !sharedPath.routes.contains(where: { $0 == branchedFrom }) {
                if notifyUserInteractiveFinish { return [] } // because the sheet is nil
                return [self.initialRoute]
            }
        }
        
        var routes: [Route] = [self.initialRoute]
        routes.append(
            contentsOf: sharedPath.routes.compactMap { $0.typedByRoute(as: Route.self) }
        )
        return routes
    }
    
    /// A Value you provide that uniquely identifies this coordinator.
    public let identifier: String
    
    /// If this were a UINavigationController, this would be your first view controller in the stack.
    public private(set) var initialRoute: Route
    public internal(set) var sheet: Route? {
        didSet {
            if let sheet {
                print("[\(String(describing: Route.self))] Sheet was set to something")
            } else {
                print("[\(String(describing: Route.self))] Sheet was set to nil")
                if let oldValue, var child = self.findChild(branchedFrom: AnyRoutable(oldValue)) {
                    print("[\(String(describing: Route.self))] Found Child.")
                    //child.goBack(.unwindToStart(finishValue: nil))
                    child.notifyUserInteractiveFinish = true
                }
            }
        }
    }
    public internal(set) var fullscreenCover: Route? {
        didSet {
            if let fullscreenCover {
                print("[\(String(describing: Route.self))] fullscreenCover was set to something")
            } else {
                print("[\(String(describing: Route.self))] fullscreenCover was set to nil")
            }
        }
    }
    
    public var notifyUserInteractiveFinish: Bool = false
    
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
    /// will get set if the sheet or fullScreenCover was nil and you need to
    private var modalFinishRoute: AnyRoutable?
    
    /// The route of the parent that spawned this Coordinator.  It will be nil if there is no parent, otherwise this should be defined.
    public private(set) var branchedFrom: AnyRoutable?
    private var isChild: Bool = false
    /// the intended way this coordinator is in use.
    private let presentationStyle: NavigationPresentationType
    
    // MARK: - Exit Callbacks
    
    /// provides the return type of the coordinator, and the type-erased coordinator that just finished. (i.e. so you can remove it)
    private var onFinish: CoordinatorFinishBlock?
    
    // MARK: - Initialization
    public convenience init(
        identifier: String,
        initialRoute: Route,
        presentationStyle: NavigationPresentationType,
        onFinish: CoordinatorFinishBlock? = nil
    ) {
        self.init(
            identifier: identifier,
            initialRoute: initialRoute,
            sharedPath: SharedNavigationPath(NavigationPath()),
            presentationStyle: presentationStyle,
            onFinish: onFinish
        )
    }
    
    /// Initializer for child coordinators with shared path reference
    public init(
        identifier: String,
        initialRoute: Route,
        sharedPath: SharedNavigationPath,
        presentationStyle: NavigationPresentationType,
        onFinish: CoordinatorFinishBlock? = nil
    ) {
        
        self.identifier = identifier
        self.sharedPath = sharedPath
        self.onFinish = onFinish
        self.initialRoute = initialRoute
        self.presentationStyle = presentationStyle
    }
   
    
    // MARK: - Child Coordinator Management
    
    /// To create a standard Coordinator that manages the given `ChildRoute`.  If you need to create custom subclasses, see `buildChildCoordinator(...)`
    /// - Parameters:
    ///   - identifier: A unique identifier to provide this coordinator so it can be retrieved properly
    ///   - branchedFrom: An Optional value that you have to provide if this child coordinator is to be used in a ChildCoordinationStack
    ///   - initialRoute: The initial route that will be used to render content
    ///   - navigationForwardType: how this coordinator is intended to be presented.
    ///   - defaultFinishValue: if the coordinator finishes due to user interaction and not programmatically, you can provide a default finish value if required.
    ///   - onFinish: provide a block to be invoked when the coordinator is finished
    /// - Returns: An instance of a Coordinator with the provided ChildRoute, with isChild set to true.
    public func createChildCoordinator<ChildRoute: Routable>(
        identifier: String,
        branchedFrom: AnyRoutable,
        initialRoute: ChildRoute,
        presentationStyle: NavigationPresentationType,
        defaultFinishValue: Any? = nil,
        onFinish: @escaping (Bool, Any?) -> Void
    ) -> Coordinator<ChildRoute> {
        
        return self.buildChildCoordinator(
            identifier: identifier,
            branchedFrom: branchedFrom,
            initialRoute: initialRoute,
            presentationStyle: presentationStyle,
            defaultFinishValue: defaultFinishValue
        ) { parent, sharedNavigationPath in
                
                return Coordinator<ChildRoute>(
                    identifier: identifier,
                    initialRoute: initialRoute,
                    sharedPath: presentationStyle == .push ? sharedPath : .init(NavigationPath()),
                    presentationStyle: presentationStyle,
                    onFinish: { [weak parent] userInitiated, anyResult, thisCoordinator in
                        
                        if !userInitiated {
                            switch presentationStyle {
                            case .sheet:
                                parent?.goBack(.dismissSheet)
                            case .fullScreenCover:
                                parent?.goBack(.dismissFullScreenCover)
                            case .push, .replaceRoot:
                                /// they will have been finished already.
                                break
                            }
                        }
                        
                        onFinish(userInitiated, anyResult)
                        // Remove the child coordinator when it finishes
                        parent?.removeChildCoordinator(thisCoordinator)
                    }
                )
            }
    }
    
    /// see the implementation for `createChildCoordinator(...)` to see how you could build your own Coordinator.
    /// if you build your own, be sure it removes the child from the parent.  See `createChildCoordinator(...)`'s onFinish implementation for an example.
    public func buildChildCoordinator<ChildRoute: Routable, CoordinatorType: Coordinator<ChildRoute>>(
        identifier: String,
        branchedFrom: AnyRoutable,
        initialRoute: ChildRoute,
        presentationStyle: NavigationPresentationType,
        defaultFinishValue: Any? = nil,
        builder: (Coordinator<Route>, SharedNavigationPath) -> CoordinatorType
    ) -> CoordinatorType {
        
        if let existingAny = childCoordinators[identifier] {
            guard let existing = existingAny.typedCoordinator(as: CoordinatorType.self) else {
                fatalError("There is a coordinator that exists with this identifier, but a different type!")
            }
            return existing
        }
        
        guard presentationStyle != .replaceRoot else {
            fatalError("Invalid configuration.  It makes no sense to replace the root view controller with a child view controller.  This could result in a NavigationStack inside a navigation stack.  Behaviour undefined as this hasn't been considered in the technical design.")
        }
        
        
        let childCoordinator = builder(self, sharedPath)
        childCoordinator.branchedFrom = branchedFrom
        childCoordinator.userData[childCoordinator.defaultFinishValueKey] = defaultFinishValue
        childCoordinator.isChild = true
        
        let anyChild = AnyCoordinator(childCoordinator)
        childCoordinators[identifier] = anyChild
        
        return childCoordinator
    }
    
    public func removeChildCoordinator(_ child: AnyCoordinator) {
        childCoordinators[child.identifier] = nil
    }
    
    func findChild(branchedFrom parentRoute: AnyRoutable?) -> AnyCoordinator? {
        
        guard let parentRoute else { return nil }
        
        print("[\(String(describing: Route.self))] Looking for child spawned with \(parentRoute.identifier)")
        for (_, coordinator) in self.childCoordinators {
            if coordinator.branchedFrom == parentRoute {
                return coordinator
            }
        }
        return nil
    }
    
    // MARK: - Finish Methods
    
    public func finish(with result: Any? = nil, userInitiated: Bool = false) {
        print("[\(String(describing: Route.self))] Coordinator finishing with payload: \(String(describing: result))")
        onFinish?(userInitiated, result ?? defaultFinishValue, AnyCoordinator(self))
    }
    
    // MARK: - Navigation Methods
    public func push<T: Routable>(_ route: T) {
        self.show(route, presentationStyle: .push)
    }
    
    public func show<T: Routable>(_ route: T, presentationStyle: NavigationPresentationType = .push) {
        
        switch presentationStyle {
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
            self.goBack(.popStackTo(AnyRoutable(self.initialRoute)))
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
    
    public func goBack(_ type: NavigationBackType = .popStack(last: 1)) {
        
        switch type {
        case .popStack(let count):
            let actualCount = min(count, localStack.count - 1) // we can only go back to the initial on the stack.
            if actualCount > 0 {
                wasProgrammaticallyPopped = true // sets a flag for viewDisappeared
                path.removeLast(actualCount)
            }
        case .popStackTo(let toAnyRoute):
            guard let typedRoute = toAnyRoute.typedByRoute(as: Route.self) else {
                fatalError("Misuse.  Read the property description.  You must pass a Route of the same type of this coordinator")
            }
            guard let lastIndex = localStack.lastIndex(where: { $0 == typedRoute }) else {
                print("WARNING: The requested route was not in the stack.  Doing nothing.")
                return
            }
            let numToRemove = localStack.count - 1 - lastIndex
            wasProgrammaticallyPopped = true
            path.removeLast(numToRemove)
            
            
        case .unwindToStart(let finishValue):
            self.popAllAndFinish(with: finishValue ?? defaultFinishValue)
            
        case .dismissSheet:
            if sheet == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a sheet that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            wasProgrammaticallyPopped = true
            isPresentingSheet = false
            sheet = nil
        case .dismissFullScreenCover:
            if fullscreenCover == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a fullscreenCover that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            wasProgrammaticallyPopped = true // this is necessary
            isPresentingFullscreenCover = false
            fullscreenCover = nil
        }
    }
    
    /// Resets the Coordinator to the state when it began while also 'finishing' as well.  (Notifies and cleans up with the parent).
    /// Typically you'll call this on a child coordinator.  If you call it on a root coordinator, (isChild == false), then finish is not invoked.
    func popAllAndFinish(with payload: Any? = nil) {
        reset()
        
        if isChild {
            self.finish(with: payload)
        }
    }
    
    /// Typically you'll only ever call this on a top-level Coordinator.  See `reset(finishingWith: ...)` if that's preferable.
    public func reset() {
        print("[\(String(describing: Route.self))] Resetting coordinator")
        
        // Clean up child coordinators
        childCoordinators.removeAll()
        
        if presentationStyle == .push || presentationStyle == .replaceRoot {
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
            
            if self.notifyUserInteractiveFinish {
                
                defaultExit?()
                self.finish(with: defaultFinishValue, userInitiated: true)
                self.notifyUserInteractiveFinish = false
                return
            }
            
            let isInNavPath = (
                sharedPath.routes.contains(where: { $0.identifier == typedRoute.identifier }) ||
                localStack.contains(where: { $0 == typedRoute })
            )
            
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
                    
                    //self.finish(with: defaultFinishValue, userInitiated: true)
                }
                
                
            }
        } else {
            // this route was not in the localStack, which suggests you popped back further than the whole stack.
            print("You popped back further than the local stack.  Assuming finished then.")
            self.finish(with: defaultFinishValue, userInitiated: true)
        }
        
        wasProgrammaticallyPopped = false
    }
    
    private var defaultFinishValue: Any? {
        let returnValue = self.userData[self.defaultFinishValueKey]
        if returnValue == nil {
            print("WARNING: No default value specified.  This could be as you intend.  If not, set .userData[coordinator.defaultFinishValueKey] to something useful when setting up your coordinator.")
        }
        return returnValue
    }
}

extension Coordinator: _CoordinatorProtocol {}
