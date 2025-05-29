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
    func makeView(with coordinator: Coordinator<MainRoute>) -> some View {
        switch self {
        case .home:
            HomeScreenView(
                viewModel: .init(
                    exits: .init(
                        onShowProfile: { userId in
                            coordinator.push(MainRoute.profile(userId: userId))
                        },
                        onShowSettings: {
                            coordinator.push(MainRoute.settings)
                        },
                        onShowAuth: {
                            coordinator.fullscreenCover = MainRoute.authFlow
                        }
                    )
                )
            )
            // We add the coordinatedView modifier to ensure the back / swipe to go back can also fire callbacks, if you need them to.
            .coordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(self),
                defaultExit: {
                    print("The Home View should never be exited via back or swipe!")
                }
            )
        case .profile(let userId): // here you want a child coordinator.
            
            //print("Create Child Coordinator")
            
            let child = coordinator.createChildCoordinator(
                identifier: "UserDetailsFlow",
                parentPushRoute: AnyRoutable(self),
                initialRoute: UserDetailsRoute.userDetail(userId),
                navigationForwardType: .push,
                defaultFinishValue: UserDetailResult(selectedAction: "Cancelled", userId: userId),
                onFinish: { userInitiated, result in
                    
                    guard let userResult = result as? UserDetailResult else {
                        fatalError("Providing a defaultFinishValue when you create your coordinator ensures that when it is dismissed by user interaction (e.g. swipe or back button), a value is provided.  Not necessary as you can also check for nil, but this remains flexible to your needs.")
                    }

                    print("Returned from User Flow: \(userResult.selectedAction) - \(userResult.userId)")
                }
            )
            
            ChildCoordinatorStack<UserDetailsRoute>()
                .environment(child) // uses the initialRoute to create the View.

        case .settings:
            let exits: SettingsView.ViewModel.NavigationExits = .init(
                onFinish: {
                    print("Did Return from Settings")
                },
                onReset: {
                    coordinator.goBack(.popToStart(finishValue: nil))
                }
            )
            SettingsView(
                viewModel: .init(
                    exits: exits
                )
            )
            .coordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(self),
                defaultExit: exits.onFinish
            )
            
        case .unauthorized:
            fatalError("Implement me!")
            
        case .authFlow:
            
            let child = coordinator.createChildCoordinator(
                identifier: "AuthFlow",
                initialRoute: AuthRoutes.login,
                navigationForwardType: .fullScreenCover,
                onFinish: { userInitiated, result in
                    if result != nil {
                        guard let userResult = result as? UserAuthResult else {
                            print("The Specification has changed!")
                            return
                        }
                        print("Returned from Auth Flow: \(userResult.userId) - isAuthenticated: \(userResult.isAuthenticated)")
                    } else {
                        coordinator.push(MainRoute.unauthorized, type: .replaceRoot)
                    }
                }
            )
            
            // a CoordinatorStack because it is its own "navigation controller" and not on top of an existing one.
            CoordinatorStack<UserDetailsRoute>()
                .environment(child) // uses the initialRoute to create the View.
        }
    }
}


enum UserDetailsRoute: Routable {
    case userDetail(String)
    case editProfile(String)
    
    
    @ViewBuilder
    func makeView(with coordinator: Coordinator<UserDetailsRoute>) -> some View {
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
                    coordinator.push(UserDetailsRoute.editProfile(userId))
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
            .coordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(self),
                defaultExit: {
                    exits.onFinish(true)
                }
            )
        case .editProfile(let userId):
            let exits = EditUserView.ViewModel.NavigationExits(
                onFinish: { userInitiated in
                    if !userInitiated {
                        coordinator.goBack()
                    }
                    print("Went back from EditUserView")
                },
                onSavedUser: { userId in
                    print("Saved User; Should pop back to Home Screen.")
                    coordinator.goBack(.popToStart(finishValue: UserDetailResult(selectedAction: "Saved", userId: userId)))
                }
            )
                
            EditUserView(viewModel: .init(exits: exits, dependencies: .init(userId: userId)))
                .coordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(self),
                    defaultExit: { exits.onFinish(true) }
                )
        }
    }
}

enum AuthRoutes: Routable {
    
    case login
    case register
    
    func makeView(with coordinator: Coordinator<AuthRoutes>) -> some View {
        fatalError("Implement Views!")
    }
}

//// Example payload types for exit callbacks
struct UserAuthResult {
    let isAuthenticated: Bool
    let userId: String
}
