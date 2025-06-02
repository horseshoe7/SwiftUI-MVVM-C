import Foundation
import SwiftUI

// MARK: - Navigation Types

public enum NavigationPresentationType {
    case push
    case sheet
    case fullscreenCover
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
    
    /// the intended initial use for the Coordinator (e.g. a NavigationStack, Sheet, Fullscreen).  replaceRoot is forbidden and will fail.
    var presentationStyle: NavigationPresentationType { get }
    
    /// if this coordinator is not a child coordinator, this will be nil. Otherwise, the parent will have to make a view for a route, and if that builder creates a child coordinator, you will provide the route in the "parent's Route type", and the child "branches" from that route.  Said another way, the parent's route that spawns the child coordinator.
    var branchedFrom: AnyRoutable? { get }
    
    /// basically to present something.
    func show<Route: Routable>(_ route: Route, presentationStyle: NavigationPresentationType)
    /// to go back
    func goBack(_ type: NavigationBackType)
    
}

/// used internally by the module.
protocol _CoordinatorProtocol: CoordinatorProtocol {
    /// used internally.  For finishing after user interactive view dismissals.
    func notifyUserInteractiveFinish()
    
    /// if you need to finish it programmatically.
    func finish(with result: Any?)
    
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
    var presentationStyle: NavigationPresentationType { _coordinator.presentationStyle }
    
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
    
    func notifyUserInteractiveFinish() {
        if let coordinator = _coordinator as? _CoordinatorProtocol {
            coordinator.notifyUserInteractiveFinish()
        }
    }
    
    func finish(with result: Any?) {
        if let coordinator = _coordinator as? _CoordinatorProtocol {
            coordinator.finish(with: result)
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
    
    init(_ path: NavigationPath = NavigationPath()) {
        self.path = path
    }
    
    public func append(_ routable: any Routable) {
        routes.append(AnyRoutable(routable))
        path.append(routable)
    }
}
