import SwiftUI

extension UserProfileView {
    
    @MainActor final class ViewModel: ObservableObject {
        
        // MARK: Dependencies
        struct Dependencies {
            let userId: String
        }
        private let dependencies: Dependencies
        
        var userId: String { dependencies.userId }
        
        // MARK: Navigation / Coordination Dependencies
        /// These represent your 'exit' points of this view (with perhaps the exeception of a 'back' action on navigation controller)
        struct NavigationExits {
            let onFinish: (_ programmatically: Bool) -> Void
            let onEditUser: (String) -> Void
        }
        private let exits: NavigationExits
        
        // MARK: Initializers
        init(exits: NavigationExits, dependencies: Dependencies) {
            print("Initializing UserProfileView.ViewModel")
            self.dependencies = dependencies
            self.exits = exits
        }
        
        // MARK: Action Definitions
        /// Actions or Events that can happen in this View Model.  Do not have to only represent user actions,
        /// but anything that can occur to potentially alter the view state.
        enum ViewAction {
            case viewDidAppear
            case viewDidDisappear
            case didPressEditUser
        }
        
        func sendAction(_ action: ViewAction) {
            switch action {
            case .viewDidAppear:
                viewDidAppear()
            case .viewDidDisappear:
                viewDidDisappear()
            case .didPressEditUser:
                self.exits.onEditUser(self.dependencies.userId)
            }
        }
    }
}

// MARK: - Private Action Handlers
private extension UserProfileView.ViewModel {
    
    func viewDidAppear() {
        // often your 'data load' trigger.
        // not to be confused with UIKit's viewDidAppear, as this isn't called when a sheet is dismissed, for example.
    }
    func viewDidDisappear() {
        // Consider cleaning up / cancelling Tasks here.
    }
}


