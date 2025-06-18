import SwiftUI

extension SettingsView {
    
    @MainActor final class ViewModel: ObservableObject {
        
        // MARK: Dependencies
        struct Dependencies {
            // you put your use case types here, so you can inject into the view model
            // let getUser: GetUserUseCaseType
        }
        private let dependencies: Dependencies
        
        // MARK: Navigation / Coordination Dependencies
        /// These represent your 'exit' points of this view (with perhaps the exeception of a 'back' action on navigation controller)
        struct NavigationExits {
            let onFinish: () -> Void
            let onReset: () -> Void
        }
        private let exits: NavigationExits
        
        // MARK: Initializers
        init(exits: NavigationExits, dependencies: Dependencies = .standard) {
            print("Initializing SettingsView.ViewModel")
            self.dependencies = dependencies
            self.exits = exits
        }
        
        // MARK: Action Definitions
        /// Actions or Events that can happen in this View Model.  Do not have to only represent user actions,
        /// but anything that can occur to potentially alter the view state.
        enum ViewAction {
            case viewDidAppear
            case viewDidDisappear
            case didTapReset
        }
        
        func sendAction(_ action: ViewAction) {
            switch action {
            case .viewDidAppear:
                viewDidAppear()
            case .viewDidDisappear:
                viewDidDisappear()
            case .didTapReset:
                self.exits.onReset()
            }
        }
    }
}

// MARK: - Private Action Handlers
private extension SettingsView.ViewModel {
    
    func viewDidAppear() {
        // often your 'data load' trigger.
        // not to be confused with UIKit's viewDidAppear, as this isn't called when a sheet is dismissed, for example.
    }
    func viewDidDisappear() {
        // Consider cleaning up / cancelling Tasks here.
    }
}

// MARK: - Default / Standard Behaviour
extension SettingsView.ViewModel.Dependencies {
    static var standard: SettingsView.ViewModel.Dependencies {
        .init() // fill this out with your standard use cases, if applicable
    }
}

