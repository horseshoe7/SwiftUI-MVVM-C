import Foundation
import SwiftUI
import HSNavigationCoordination

// MARK: - Example Usage

//// Example payload types for exit callbacks
struct UserDetailResult {
    let selectedAction: String
    let userId: String
}

// Example route types
enum MainRoute: Routable {
    case unauthorized
    case authFlow
    case home
    case profile(userId: String)
    case settings
    
    @ViewBuilder
    func makeView(with coordinator: Coordinator<MainRoute>, presentationStyle: NavigationPresentationType) -> some View {
        switch self {
        case .home:
            HomeScreenView(
                viewModel: .init(
                    exits: .init(
                        onShowProfile: { userId in
                            coordinator.show(MainRoute.profile(userId: userId))
                        },
                        onShowSettings: {
                            coordinator.show(MainRoute.settings)
                        },
                        onShowAuth: {
                            coordinator.show(MainRoute.authFlow, presentationStyle: .sheet)
                        }
                    )
                )
            )
            .onDefaultExit {
                print("The Home View should never be exited via back or swipe!")
            }
            
        case .profile(let userId): // here you want a child coordinator.
            
            let child = coordinator.createChildCoordinator(
                identifier: "UserDetailsFlow",
                branchedFrom: AnyRoutable(self),
                initialRoute: UserDetailsRoute.userDetail(userId),
                presentationStyle: presentationStyle,
                defaultFinishValue: UserDetailResult(selectedAction: "Cancelled", userId: userId),
                onFinish: { userInitiated, result in
                    
                    guard let userResult = result as? UserDetailResult else {
                        fatalError("Providing a defaultFinishValue when you create your coordinator ensures that when it is dismissed by user interaction (e.g. swipe or back button), a value is provided.  Not necessary as you can also check for nil, but this remains flexible to your needs.")
                    }

                    print("Returned from User Flow: \(userResult.selectedAction) - \(userResult.userId)")
                }
            )
            
            // a "ChildCoordinatorStack" is one that is sharing the same NavigationPath and NavigationStack as its parent.
            ChildCoordinatorStack<UserDetailsRoute>()
                .environment(child) // uses the initialRoute to create the View.

        case .settings:
            let exits: SettingsView.ViewModel.NavigationExits = .init(
                onFinish: {
                    print("Did Return from Settings")
                },
                onReset: {
                    coordinator.goBack(.unwindToStart(finishValue: nil))
                }
            )
            SettingsView(
                viewModel: .init(
                    exits: exits
                )
            )
            .onDefaultExit {
                exits.onFinish()
            }
            
        case .unauthorized:
            UnauthorizedView(
                viewModel: .init(
                    exits: .init(
                        onTappedAuthorize: {
                            coordinator.show(MainRoute.authFlow, presentationStyle: .fullscreenCover)
                        }
                    )
                )
            )
            .onDefaultExit {
                print("This view should have no default exit as it becomes a root view.")
            }
            
        case .authFlow:
            
            let child = coordinator.createChildCoordinator(
                identifier: "AuthFlow",
                branchedFrom: AnyRoutable(self),
                initialRoute: AuthRoutes.login,
                presentationStyle: presentationStyle,
                defaultFinishValue: UserAuthResult(isAuthenticated: false, userId: "---"),
                onFinish: { userInitiated, result in
                    guard let userResult = result as? UserAuthResult else {
                        print("The Specification has changed!")
                        return
                    }
                    print("Returned from Auth Flow: \(userResult.userId) - isAuthenticated: \(userResult.isAuthenticated)")
                    
                    if userResult.isAuthenticated {
                        coordinator.show(MainRoute.home, presentationStyle: .replaceRoot)
                    } else {
                        coordinator.show(MainRoute.unauthorized, presentationStyle: .replaceRoot)
                    }
                }
            )
            
            // the combination of a .fullScreenCover presentation style above, and a CoordinatorStack here below
            // means that it will present a NavigationStack with its own navigation path modally.
            
            // a CoordinatorStack because it is its own "navigation controller" and not on top of an existing one.
            CoordinatorStack<AuthRoutes>()
                .environment(child) // uses the initialRoute to create the View.
        }
    }
}


enum UserDetailsRoute: Routable {
    case userDetail(String)
    case editProfile(String)
    
    
    @ViewBuilder
    func makeView(with coordinator: Coordinator<UserDetailsRoute>, presentationStyle: NavigationPresentationType) -> some View {
        switch self {
        case .userDetail(let userId):
            let exits = UserProfileView.ViewModel.NavigationExits(
                onFinish: { userInitiated in
                    print("Did Go back from User Detail")
                    if !userInitiated {
                        coordinator.goBack()
                    }
                },
                onEditUser: { userId in
                    coordinator.show(UserDetailsRoute.editProfile(userId))
                }
            )
            UserProfileView(
                viewModel: .init(
                    exits: exits,
                    dependencies: .init(
                        userId: userId
                    )
                )
            )
            .onDefaultExit {
                exits.onFinish(true)
            }
            
        case .editProfile(let userId):
            let exits = EditUserView.ViewModel.NavigationExits(
                onFinish: { userInitiated in
                    if !userInitiated {
                        coordinator.goBack()
                    }
                    print("Went back from EditUserView")
                },
                onSavedUser: { userId in
                    // this is actually incorrect; a child can only unwind to it's start, which is the .userDetail
                    print("Saved User; Should pop back to Home Screen.")
                    
                    // this is unwinding to the start of the coordinator, where it should be unwinding to the parent that spawned it.
                    coordinator.goBack(.unwindToStart(finishValue: UserDetailResult(selectedAction: "Saved", userId: userId)))
                }
            )
                
            EditUserView(viewModel: .init(exits: exits, dependencies: .init(userId: userId)))
                .onDefaultExit {
                    exits.onFinish(true)
                }
        }
    }
}

enum AuthRoutes: Routable {
    
    case login
    case register
    
    func makeView(with coordinator: Coordinator<AuthRoutes>, presentationStyle: NavigationPresentationType) -> some View {
        FakeAuthFlowView(
            viewModel: .init(
                exits: .init(
                    onFinish: { result in
                        coordinator.goBack(.unwindToStart(finishValue: result)) // NOT dismissFullscreenCover!
                    }, showSignUp: {
                        // Here we demonstrate how the Coordinator can store data in between screen flows.... (see below)
                        coordinator.userData["userPrompt"] = "Stephen"
                        coordinator.show(AuthRoutes.register)
                    }
                ),
                dependencies: .init(
                    isSignInView: self == .login,
                    userPromptName: coordinator.userData["userPrompt"] as? String // ...and then retrieved in later screens
                )
            )
        )
    }
}


