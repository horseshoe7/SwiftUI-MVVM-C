import Foundation
import SwiftUI

// MARK: - Core Protocols

public protocol Routable: Hashable, Identifiable {
    associatedtype Content: View
    
    
    /// A factory method where you create and configure your view/viewModel and exits.
    /// - Parameters:
    ///   - coordinator: The coordinator that requires the view for a route that was invoked with `.show(...)`
    ///   - presentationStyle: the presentationStyle passed into the `.show(...)` method.  Only relevant if you need to create a child coordinator.
    /// - Returns: a View that has been configured for coordination.  Be sure you have added the coordinatedView modifier to ensure a defaultExit has been applied.
    @MainActor
    func makeView(with coordinator: Coordinator<Self>) -> Content
}

public extension Routable {
    /// This was designed on the assumption you're using enums as  your Routable type.
    var identifier: String {
        return id
    }
    
    var id: String {
        return "\(String(describing: type(of: self))).\(String(describing: self))"
    }
}

/// A type-erased form that makes it possible to pass the routes around (not for generation, but for comparison / stack management).
public struct AnyRoutable: Hashable {

    fileprivate let _routable: any Routable
    public let identifier: String
    
    public init<T: Routable>(_ routable: T) {
        self._routable = routable
        self.identifier = routable.identifier
    }
    
    public func typedByRoute<T: Routable>(as type: T.Type) -> T? {
        return _routable as? T
    }
    
    public static func == (lhs: AnyRoutable, rhs: AnyRoutable) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
