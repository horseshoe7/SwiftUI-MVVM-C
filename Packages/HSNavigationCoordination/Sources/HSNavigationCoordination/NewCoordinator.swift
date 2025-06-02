import Foundation
import SwiftUI

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


@Observable
public class NewCoordinator<Route: Routable>: _CoordinatorNode, CoordinatorProtocol {
    
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
    
//    override func removeFromParent() {
//        parentNode?.removeChild(withIdentifier: self.identifier)
//    }
    
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
            
        case .fullScreenCover:
            guard let typedRoute = route as? Route else {
                fatalError("Warning: Cannot present fullScreenCover with cross-type route from typed coordinator")
            }
            print("[\(String(describing: Route.self))] Presenting FullScreenCover: \(typedRoute)")
            fullScreenCover = typedRoute // sets a private var here too.
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
            wasProgrammaticallyPopped = true // sets a flag for viewDisappeared.
            path.removeLast(numToRemove)
            
            
        case .unwindToStart(let finishValue):
            // here you should notify the parent to unwind the child.
            self.parentNode?.finish(self, result: finishValue ?? defaultFinishValue, userInitiated: false)
            
        case .dismissSheet:
            if sheet == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a sheet that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            sheet = nil
            _presentedSheet = nil // this is to indicate it wasn't userInitiated.
            
        case .dismissFullScreenCover:
            if fullScreenCover == nil {
                print("[\(String(describing: Route.self))] Warning: You're trying to dismiss a fullscreenCover that was already nil.  Were you trying to dismiss your child coordinator that was presented as a sheet?  Use .unwindToStart(...) instead.")
            }
            
            fullScreenCover = nil
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
            checkForUserInitiatedFinishesInChildren(presentationStyle: .push)
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
            if let sheet {
                _presentedSheet = sheet
            } else {
                checkForUserInitiatedFinishesInChildren(presentationStyle: .sheet)
            }
        }
    }
    
    
    // MARK: Presenting FullScreenCover
    
    /// And we compare here to determine in another method if that happened.
    private var _presentedFullScreenCover: Route?
    /// SwiftUI can set this to nil via a binding... (see `_presentedFullScreenCover`)
    public internal(set) var fullScreenCover: Route? {
        didSet {
            if let fullScreenCover {
                _presentedFullScreenCover = fullScreenCover
            } else {
                checkForUserInitiatedFinishesInChildren(presentationStyle: .fullScreenCover) // you check for a child with a branchedBy with _presentedFullScreenCover
            }
            // we don't set it to nil, because we look for a mismatch in another method.
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
        super.init(identifier: identifier)
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
        onFinish: @escaping (_ userInitiated: Bool, _ result: Any?) -> Void
    ) -> NewCoordinator<ChildRoute> {
        
        return self.buildChildCoordinator(
            identifier: identifier,
            branchedFrom: branchedFrom,
            initialRoute: initialRoute,
            presentationStyle: presentationStyle,
            defaultFinishValue: defaultFinishValue
        ) { parent, sharedNavigationPath in
                
                return NewCoordinator<ChildRoute>(
                    identifier: identifier,
                    initialRoute: initialRoute,
                    sharedPath: presentationStyle == .push ? sharedPath : .init(NavigationPath()),
                    presentationStyle: presentationStyle,
                    onFinish: { [weak parent] userInitiated, anyResult, thisCoordinator in
                        
                        onFinish(userInitiated, anyResult)
                        // Remove the child coordinator when it finishes
                        parent?.removeChildCoordinator(thisCoordinator)
                    }
                )
            }
    }
    
    /// see the implementation for `createChildCoordinator(...)` to see how you could build your own Coordinator.
    /// if you build your own, be sure it removes the child from the parent.  See `createChildCoordinator(...)`'s onFinish implementation for an example.
    public func buildChildCoordinator<ChildRoute: Routable, CoordinatorType: NewCoordinator<ChildRoute>>(
        identifier: String,
        branchedFrom: AnyRoutable,
        initialRoute: ChildRoute,
        presentationStyle: NavigationPresentationType,
        defaultFinishValue: Any? = nil,
        builder: (NewCoordinator<Route>, SharedNavigationPath) -> CoordinatorType
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
        
        guard !wasOnceFinished else {
            print("Warning: Attempting to finish a coordinator that was already finished.")
        }
        wasOnceFinished = true
        self.onFinish?(userInitiated, result ?? defaultFinishValue, AnyCoordinator(self))
    }
    
    func finish(with result: Any?) {
        finishThis(with: result, userInitiated: false)
    }
    
    override func finish(_ child: _CoordinatorNode, result: Any? = nil, userInitiated: Bool = false) {
        
        guard let childCoordinator = self.childCoordinators[child.identifier] else {
            print("You tried to finish a child that didn't belong to this parent!")
            return
        }
        
        if userInitiated {
            guard result == nil else {
                fatalError("Misuse.  A user initiated finish should only be able to use its defaultReturnValue")
                return
            }
            // if it's user initiated, you just need to call the completion block.
            // but this has to happen AFTER the viewsDisappeared?  Yes.  So state is set consistently.
            // there will be the case where it might replace 'later'.
            // in that case you'll have to replace before presenting, then depending on your result, replace again to the appropriate screen, for example.
            childCoordinator.notifyUserInteractiveFinish()
            return
        }
        
        // find the child whose branchedBy is sheet, fullScreenCover or route in sharedPath, so to determine what kind of unwind you have to do.
        guard let branchedFrom = childCoordinator.branchedFrom else {
            fatalError("Impossible state.  A child should always have a branchedFrom")
        }
        
        if let sheet, AnyRoutable(sheet) == branchedFrom {
            // then we need to programmatically dismiss the sheet and finish.
            self.goBack(.dismissSheet)
            childCoordinator.finish(with: result)
            return
        }
        
        if let fullScreenCover, AnyRoutable(fullScreenCover) == branchedFrom {
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
            
            for (identifier, childNode) in childNodes {
                
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
                    if let branchedFrom = anyChild.branchedFrom, branchedFrom == AnyRoutable(_presentedSheet) {
                        anyChild.notifyUserInteractiveFinish()
                    }
                }
            }
            
        case .fullScreenCover:
            // you check for a child with a branchedBy with _presentedFullscreenCover
            if let _presentedFullScreenCover, fullScreenCover == nil {
                // SwiftUI dismissed the sheet via a binding.
                
                // you check for a child with a branchedBy with _presentedSheet
                self.childCoordinators.forEach { identifier, anyChild in
                    if let branchedFrom = anyChild.branchedFrom, branchedFrom == AnyRoutable(_presentedFullScreenCover) {
                        anyChild.notifyUserInteractiveFinish()
                    }
                }
            }
            
        case .replaceRoot:
            
        }
    }
    
    
}
