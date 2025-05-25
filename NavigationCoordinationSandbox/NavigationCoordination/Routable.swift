import Foundation
import SwiftUI

// MARK: - Core Protocols

protocol Routable: Hashable, Identifiable {
    associatedtype Content: View
    
    @MainActor
    func makeView(with coordinator: Coordinator<Self>) -> Content
}

extension Routable {
    /// This was designed on the assumption you're using enums as  your Routable type.
    var identifier: String {
        return "\(String(describing: type(of: self))).\(String(describing: self))"
    }
}

/// A type-erased form that makes it possible to pass the routes around (not for generation, but for comparison / stack management).
struct AnyRoutable: Hashable {

    fileprivate let _routable: any Routable
    let identifier: String
    
    init<T: Routable>(_ routable: T) {
        self._routable = routable
        self.identifier = routable.identifier
    }
    
    func typedByRoute<T: Routable>(as type: T.Type) -> T? {
        return _routable as? T
    }
    
    static func == (lhs: AnyRoutable, rhs: AnyRoutable) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
