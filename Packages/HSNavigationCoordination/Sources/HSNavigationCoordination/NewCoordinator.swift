import Foundation
import SwiftUI


@Observable
public class Coordinator<Route: Routable>: _CoordinatorNode, CoordinatorProtocol {
    
    /// If this were a UINavigationController, this would be your first view controller in the stack.
    public private(set) var initialRoute: Route
    public private(set) var branchedFrom: AnyRoutable?
    
    // MARK: - Generic Data Storage
    
    /// you can use a simple dictionary to avoid having to construct your own Coordinator types just to store data.
    public var userData: [String: Any] = [:]
    
    private var defaultFinishValue: Any? {
        let returnValue = self.userData[_CoordinatorNode.defaultFinishValueKey]
        if returnValue == nil {
            print("WARNING: No default value specified.  This could be as you intend.  If not, set .userData[coordinator.defaultFinishValueKey] to something useful when setting up your coordinator.")
        }
        return returnValue
    }
    
    // MARK: - Node Tree Management
    private var childCoordinators: [String: AnyCoordinator] = [:]
    
    // Tree structure operations
    func addChildCoordinator(_ child: AnyCoordinator, node: _CoordinatorNode) {
        super.addChild(node)
        node.parentNode = self
        childCoordinators[child.identifier] = child
    }
    
    public func removeChildCoordinator(_ child: AnyCoordinator) {
        childCoordinators[child.identifier] = nil
        super.removeChild(withIdentifier: child.identifier)
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
            _lastPushed = typedRoute
            wasProgrammaticallyPopped = false
            sharedPath.append(typedRoute)
            
        case .replaceRoot:
            guard let typedRoute = route as? Route else {
                fatalError("Misuse!  You should not replace routes of different types.")
            }
            print("[\(String(describing: Route.self))] Replacing Stack to typed route: \(route)")
            self.goBack(.popStackTo(AnyRoutable(self.initialRoute)))
            
            self.initialRoute = typedRoute
            
        case .sheet:
            guard let typedRoute = route as? Route else {
                fatalError("Warning: Cannot present sheet with cross-type route from typed coordinator")
            }
            print("[\(String(describing: Route.self))] Presenting Sheet: \(typedRoute)")
            sheet = typedRoute // sets a private var here too.
            _presentedSheet = typedRoute
            
        case .fullscreenCover:
            guard let typedRoute = route as? Route else {
                fatalError("Warning: Cannot present fullscreenCover with cross-type route from typed coordinator")
            }
            print("[\(String(describing: Route.self))] Presenting FullScreenCover: \(typedRoute)")
            fullscreenCover = typedRoute // sets a private var here too.
            _presentedFullScreenCover = typedRoute
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
            let numToRemove = max(0, localStack.count - lastIndex)
            wasProgrammaticallyPopped = true // sets a flag for viewDisappeared.
            path.removeLast(min(numToRemove, path.count))
            
            
        case .unwindToStart(let finishValue):
            if let parentNode {
                parentNode.finish(self, result: finishValue ?? defaultFinishValue, userInitiated: false)
            } else {
                // essentially resets it.
                wasProgrammaticallyPopped = true
                path.removeLast(path.count)
                sheet = nil
                fullscreenCover = nil
            }
            
        case .dismissSheet:
            if sheet == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a sheet that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            sheet = nil
            _presentedSheet = nil // this is to indicate it wasn't userInitiated.
            
        case .dismissFullScreenCover:
            if fullscreenCover == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a fullscreenCover that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            
            fullscreenCover = nil
            _presentedFullScreenCover = nil
        }
    }
    
    // MARK: - Navigation States
    
    // MARK: Navigation Stacks
    
    private var sharedPath: SharedNavigationPath
    var path: NavigationPath {
        get { sharedPath.path }
        set {
            sharedPath.path = newValue
            if !wasProgrammaticallyPopped {
                checkForUserInitiatedFinishesInChildren(presentationStyle: .push)
            }
        }
    }
    
    // MARK: Navigation Stack
    
    /// you use this to check your stack.
    private var _lastPushed: Route?
    /// This is taken to mean pop or replaced.
    private var wasProgrammaticallyPopped = false
    
    /// mostly for debugging.  If you need to know what routes in the `sharedPath` are managed by this Coordinator.
    public var localStack: [Route] {
        
        // in the even this is a child on the same NavigationStack as its parent.
        if let branchedFrom {
            if !sharedPath.routes.contains(where: { $0 == branchedFrom }) {
                return []
            }
        }
        
        var routes: [Route] = [self.initialRoute]
        routes.append(
            contentsOf: sharedPath.routes.compactMap { $0.typedByRoute(as: Route.self) }
        )
        return routes
    }
    
    
    // MARK: Presenting Sheet
    
    private var _presentedSheet: Route?
    /// SwiftUI can set this to nil via a binding... (see `_presentedSheet`)
    public internal(set) var sheet: Route? {
        didSet {
            if self.sheet == nil {
                checkForUserInitiatedFinishesInChildren(presentationStyle: .sheet)
            }
        }
    }
    
    
    // MARK: Presenting FullScreenCover
    
    /// And we compare here to determine in another method if that happened.
    private var _presentedFullScreenCover: Route?
    /// SwiftUI can set this to nil via a binding... (see `_presentedFullScreenCover`)
    public internal(set) var fullscreenCover: Route? {
        didSet {
            if self.fullscreenCover == nil {
                checkForUserInitiatedFinishesInChildren(presentationStyle: .fullscreenCover) // you check for a child with a branchedBy with _presentedFullScreenCover
            }
        }
    }
    
    // MARK: - Exit Callbacks
    
    /// provides the return type of the coordinator, and the type-erased coordinator that just finished. (i.e. so you can remove it)
    private var onFinish: CoordinatorFinishBlock?
    private var wasOnceFinished: Bool = false
    
    private var shouldNotifyUserInteractiveFinish: Bool = false
    
    // MARK: - Private Members
    
    /// the intended way this coordinator is in use.
    public let presentationStyle: NavigationPresentationType
    
    
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
        
        self.sharedPath = sharedPath
        self.onFinish = onFinish
        self.initialRoute = initialRoute
        self.presentationStyle = presentationStyle
        super.init(identifier: identifier)
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
        onFinish: @escaping (_ userInitiated: Bool, _ result: Any?) -> Void
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
                        
                        // Remove the child coordinator when it finishes
                        parent?.removeChildCoordinator(thisCoordinator)
                        onFinish(userInitiated, anyResult)
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
        childCoordinator.userData[_CoordinatorNode.defaultFinishValueKey] = defaultFinishValue
        
        let anyChild = AnyCoordinator(childCoordinator)
        self.addChildCoordinator(anyChild, node: childCoordinator)
        
        return childCoordinator
    }
    
    // MARK: - Finish Methods
    
    func notifyUserInteractiveFinish() {
        self.shouldNotifyUserInteractiveFinish = true
    }
    
    /// should be invoked by a parent, ideally, or indirectly via shouldNotifyUserInteractiveFinish
    private func finishThis(with result: Any? = nil, userInitiated: Bool = false) {
        
        print("[\(String(describing: Route.self))] - \(self.identifier) - onFinish \(userInitiated ? "(user initated)" : "")")
        
        guard !wasOnceFinished else {
            print("Warning: Attempting to finish a coordinator that was already finished.  Doing nothing.")
            return
        }
        wasOnceFinished = true
        self.onFinish?(userInitiated, result ?? defaultFinishValue, AnyCoordinator(self))
    }
    
    func finish(with result: Any?, userInitiated: Bool) {
        finishThis(with: result, userInitiated: userInitiated)
    }
    
    override func finish(_ child: _CoordinatorNode, result: Any? = nil, userInitiated: Bool = false) {
        
        guard let childCoordinator = self.childCoordinators[child.identifier] else {
            print("You tried to finish a child that didn't belong to this parent!")
            return
        }
        
        if userInitiated {
            // if it's user initiated, you just need to call the completion block.
            // but this has to happen AFTER the viewsDisappeared?  Yes.  So state is set consistently.
            // there will be the case where it might replace 'later'.
            // in that case you'll have to replace before presenting, then depending on your result, replace again to the appropriate screen, for example.
            childCoordinator.finish(with: result, userInitiated: true)
            return
        }
        
        // find the child whose branchedBy is sheet, fullscreenCover or route in sharedPath, so to determine what kind of unwind you have to do.
        guard let branchedFrom = childCoordinator.branchedFrom else {
            fatalError("Impossible state.  A child should always have a branchedFrom")
        }
        
        if let sheet, AnyRoutable(sheet) == branchedFrom {
            // then we need to programmatically dismiss the sheet and finish.
            self.goBack(.dismissSheet)
            childCoordinator.finish(with: result)
            return
        }
        
        if let fullscreenCover, AnyRoutable(fullscreenCover) == branchedFrom {
            // then we need to programmatically dismiss the sheet and finish.
            self.goBack(.dismissFullScreenCover)
            childCoordinator.finish(with: result)
            return
        }
        
        if self.sharedPath.routes.contains(where: { $0 == branchedFrom }) {
            self.goBack(.popStackTo(branchedFrom))
            if self.sharedPath.path.count > 0 {
                self.goBack(.popStack(last: 1))
            }
            childCoordinator.finish(with: result)
            return
        }
    }
    
    /// the idea here is that
    func checkForUserInitiatedFinishesInChildren(presentationStyle: NavigationPresentationType) {
        
        switch presentationStyle {
        case .push:
            // you check for children with a parent route of the same type as this one, presentation type being .push, and the shared stack's last route being of this coordinator's type (i.e. child routes not on stack).
            
            for (identifier, _) in childNodes {
                
                guard let childCoordinator = self.childCoordinators[identifier] else {
                    fatalError("Inconsistency.  There should always be a child coordinator for any childNode")
                }
                if childCoordinator.presentationStyle != .push {
                    continue
                }
                
                guard let branchedFrom = childCoordinator.branchedFrom else {
                    fatalError("Inconsistency.  All child coordinators need to be branched from a parent.")
                }
                
                let thisLast = self.sharedPath.routes.last ?? AnyRoutable(self.initialRoute)
                if thisLast.routeType == branchedFrom.routeType {
                    // then this child was finished via userInteraction
                    childCoordinator.notifyUserInteractiveFinish() // you might have to force this because the viewDisappeared probably fired already.
                    //childCoordinator.finishedByUserInteraction()
                }
            }
            
            // if child's localStack == [] then it was a user initiated finish?
            
            
            
        case .sheet:
            if let _presentedSheet, sheet == nil {
                // SwiftUI dismissed the sheet via a binding.
                
                // you check for a child with a branchedBy with _presentedSheet
                self.childCoordinators.forEach { identifier, anyChild in
                    if anyChild.presentationStyle == .sheet {
                        if let branchedFrom = anyChild.branchedFrom, branchedFrom == AnyRoutable(_presentedSheet) {
                            self._presentedSheet = nil // because we've now just handled it.
                            anyChild.notifyUserInteractiveFinish()
                        }
                    }
                }
            }
            
        case .fullscreenCover:
            // you check for a child with a branchedBy with _presentedFullscreenCover
            if let _presentedFullScreenCover, fullscreenCover == nil {
                // SwiftUI dismissed the sheet via a binding.
                
                // you check for a child with a branchedBy with _presentedSheet
                self.childCoordinators.forEach { identifier, anyChild in
                    if anyChild.presentationStyle == .fullscreenCover {
                        if let branchedFrom = anyChild.branchedFrom, branchedFrom == AnyRoutable(_presentedFullScreenCover) {
                            self._presentedFullScreenCover = nil // it fulfilled its purpose.
                            anyChild.notifyUserInteractiveFinish()
                        }
                    }
                }
            }
            
        case .replaceRoot:
            fatalError("Implement me!")
        }
    }
    
    func viewDisappeared(route: AnyRoutable, defaultExit: ViewDefaultFinishBlock?) {

        /* the purpose of this method is to determine if you should invoke the default exit and/or tell the parent to finish this child.
         
         So, viewDisappeared can be tricky, because it's literally when it disappears.
         Situations where a given view disappears:
         - A) A new view is pushed onto the stack (over top of it)
         - B) the view itself is popped from the stack
         - C) the stack is popped to root, and the view was in the collection of views that were popped.
         - D) a new view is presented over top
         - E) the view itself was the presented view.
         
         */
        
        print("[\(String(describing: Route.self))] View with Route `\(route.identifier)` disappeared. Programmatically: \(wasProgrammaticallyPopped)")
        
        // it means a SwiftUI binding set sheet to nil (i.e. via user interaction)
        // AND don't confuse this being nil with the child-parent relationship.
        // viewDisappeared methods are mostly in the child coordinator whereas sheet is presenting the child.
        if _presentedSheet != nil, sheet == nil {
            _presentedSheet = nil
            print("defaultExit will be called in response to sheet dismissal.")
            defaultExit?()
            return
        }
        
        // it means a SwiftUI binding set fullscreenCover to nil. (i.e. via user interaction)
        if _presentedFullScreenCover != nil, fullscreenCover == nil {
            _presentedFullScreenCover = nil
            print("defaultExit will be called in response to sheet dismissal.")
            defaultExit?()
            return
        }
        
        guard !wasProgrammaticallyPopped else {
            // nothing to do because we programmatically changed things, thus exits were properly invoked.
            wasProgrammaticallyPopped = false
            return
        }
        
        if let typedRoute = route.typedByRoute(as: Route.self) {
            
            if self.shouldNotifyUserInteractiveFinish {
                self.shouldNotifyUserInteractiveFinish = false
                defaultExit?()
                self.parentNode?.finish(self, result: defaultFinishValue, userInitiated: true)
                return
            }
            
            let isInNavPath = (
                sharedPath.routes.contains(where: { $0.identifier == typedRoute.identifier }) ||
                localStack.contains(where: { $0 == typedRoute })
            )
            
            if isInNavPath {
                print("Disappeared due to something being pushed on top of it.")
            } else {
                if typedRoute != self.initialRoute {
                    print("[\(String(describing: Route.self)).\(String(describing: typedRoute))] Route was popped by back/swipe")
                    print("defaultExit will be called.")
                    defaultExit?()
                } else if typedRoute == self.initialRoute && self.isChild {
                    // this means the view disappeared is the first in the stack, thus the stack was automatically popped.
                    print("defaultExit will be called then the onFinish method will likely be called.")
                    defaultExit?()
                    
                    //self.finish(with: defaultFinishValue, userInitiated: true)
                }
            }
        }
        
        wasProgrammaticallyPopped = false
    }
}

extension Coordinator: _CoordinatorProtocol {}

// MARK: - CoordinatorNode baseclass

/// This is used to establish a type agnostic tree node structure so that a child can retain a weak reference to its parent
public class _CoordinatorNode {
    
    public static let defaultFinishValueKey = "CoordinatorDefaultFinishValueKey"
    
    /// A Value you provide that uniquely identifies this coordinator.
    public let identifier: String
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    weak var parentNode: _CoordinatorNode?
    var childNodes: [String: _CoordinatorNode] = [:]
    
    // Tree structure operations
    func addChild(_ child: _CoordinatorNode) {
        child.parentNode = self
        guard childNodes[child.identifier] == nil else {
            print("Warning; tried to add a node with identifier that already exists as a child.  Ignoring this.")
            return
        }
        childNodes[child.identifier] = child
    }
    
    func removeFromParent() {
        parentNode?.removeChild(withIdentifier: self.identifier)
    }
    
    func removeChild(withIdentifier identifier: String) {
        if let existing = childNodes[identifier] {
            existing.parentNode = nil
            childNodes[identifier] = nil
        }
    }
    
    // Tree queries that don't care about data type
    var depth: Int {
        return (parentNode?.depth ?? -1) + 1
    }
    
    var isRoot: Bool { parentNode == nil }
    var isChild: Bool { parentNode != nil }
    var isLeaf: Bool { childNodes.isEmpty }
    
    func ancestorCount() -> Int {
        return parentNode?.ancestorCount() ?? 0 + 1
    }
    
    func findRoot() -> _CoordinatorNode {
        return parentNode?.findRoot() ?? self
    }
    
    // Tree traversal
    func preOrderTraversal(_ visit: (_CoordinatorNode) -> Void) {
        visit(self)
        childNodes.forEach { (identifier: String, node: _CoordinatorNode) in
            node.preOrderTraversal(visit)
        }
    }
    
    func postOrderTraversal(_ visit: (_CoordinatorNode) -> Void) {
        childNodes.forEach { (identifier: String, node: _CoordinatorNode) in
            node.postOrderTraversal(visit)
        }
        visit(self)
    }
    
    // MARK: - Abstract Methods
    
    func finish(_ child: _CoordinatorNode, result: Any? = nil, userInitiated: Bool = false) {
        
        fatalError("You need to override this in your subclass.")
    }
}
