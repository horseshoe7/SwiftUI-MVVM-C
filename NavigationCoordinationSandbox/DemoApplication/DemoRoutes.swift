import Foundation
import SwiftUI


// MARK: - Example Usage

//// Example payload types for exit callbacks
struct UserDetailResult {
    let selectedAction: String
    let userId: String
}

// Example route types
enum MainRoute: Routable {
    case home
    case profile(userId: String)
    case settings
    
    var id: String { String(describing: self) }
    
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
                initialRoute: UserDetailsRoute.userDetail(userId),
                onFinish: { result in
                    if result != nil {
                        guard let userResult = result as? UserDetailResult else {
                            print("The Specification has changed!")
                            return
                        }
                        print("Returned from User Flow: \(userResult.selectedAction) - \(userResult.userId)")
                    }
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
                    coordinator.reset()
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
        }
    }
}


enum UserDetailsRoute: Routable {
    case userDetail(String)
    case editProfile(String)
    
    var id: String { String(describing: self) }
    
    @ViewBuilder
    func makeView(with coordinator: Coordinator<UserDetailsRoute>) -> some View {
        switch self {
        case .userDetail(let userId):
            let exits = UserProfileView.ViewModel.NavigationExits(
                onFinish: { programmatically in
                    print("Did Go back from User Detail")
                    if programmatically {
                        coordinator.pop()
                    }
                    coordinator.finish(with: nil)
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
                    exits.onFinish(false)
                }
            )
        case .editProfile(let userId):
            let exits = EditUserView.ViewModel.NavigationExits(
                onFinish: { programatically in
                    if programatically {
                        coordinator.pop()
                    }
                    print("Went back from EditUserView")
                },
                onSavedUser: { userId in
                    print("Saved User; Should pop back to Home Screen.")
                    coordinator.reset(finishingWith: UserDetailResult.init(selectedAction: "Saved", userId: userId))
                }
            )
                
            EditUserView(viewModel: .init(exits: exits, dependencies: .init(userId: userId)))
                .coordinatedView(
                    coordinator: AnyCoordinator(coordinator),
                    route: AnyRoutable(self),
                    defaultExit: { exits.onFinish(false) }
                )
        }
    }
}
