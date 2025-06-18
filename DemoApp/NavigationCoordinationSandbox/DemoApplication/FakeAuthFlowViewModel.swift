import SwiftUI

//// Example payload types for exit callbacks
struct UserAuthResult {
    let isAuthenticated: Bool
    let userId: String
}

extension FakeAuthFlowView {
    
    @MainActor final class ViewModel: ObservableObject {
        
        let isSignInView: Bool
        let userPrompt: String
        
        // MARK: Dependencies
        struct Dependencies {
            let isSignInView: Bool
            let userPromptName: String?
        }
        private let dependencies: Dependencies
        
        // MARK: Navigation / Coordination Dependencies
        /// These represent your 'exit' points of this view (with perhaps the exeception of a 'back' action on navigation controller)
        struct NavigationExits {
            let onFinish: (UserAuthResult) -> Void
            let showSignUp: () -> Void
        }
        private let exits: NavigationExits
        
        // MARK: Initializers
        init(exits: NavigationExits, dependencies: Dependencies) {
            self.dependencies = dependencies
            self.exits = exits
            
            self.isSignInView = dependencies.isSignInView
            self.userPrompt = "Sign Up, \(dependencies.userPromptName ?? "New Guy")"
        }
        
        // MARK: Action Definitions
        /// Actions or Events that can happen in this View Model.  Do not have to only represent user actions,
        /// but anything that can occur to potentially alter the view state.
        enum ViewAction {
            case viewDidAppear
            case viewDidDisappear
            case tappedSignUp
            case tappedSuccess
            case tappedFailed
        }
        
        func sendAction(_ action: ViewAction) {
            switch action {
            case .viewDidAppear:
                viewDidAppear()
            case .viewDidDisappear:
                viewDidDisappear()
            case .tappedSignUp:
                self.exits.showSignUp()
            case .tappedSuccess:
                self.exits.onFinish(UserAuthResult(isAuthenticated: true, userId: "TestyTester"))
            case .tappedFailed:
                self.exits.onFinish(UserAuthResult(isAuthenticated: false, userId: "(none)"))
            }
        }
    }
}

// MARK: - Private Action Handlers
private extension FakeAuthFlowView.ViewModel {
    
    func viewDidAppear() {
        // often your 'data load' trigger.
        // not to be confused with UIKit's viewDidAppear, as this isn't called when a sheet is dismissed, for example.
    }
    func viewDidDisappear() {
        // Consider cleaning up / cancelling Tasks here.
    }
}

