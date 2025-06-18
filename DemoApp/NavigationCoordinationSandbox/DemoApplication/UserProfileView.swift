import SwiftUI

struct UserProfileView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            Color.yellow
                .ignoresSafeArea()
            
            VStack {
                Text("UserProfileView")
                Text("UserID: \(viewModel.userId)")
                
                Button(
                    action: {
                        viewModel.sendAction(.didPressEditUser)
                    },
                    label: {
                        Text("Edit User")
                    }
                )
            }
        }
        .onAppear {
            viewModel.sendAction(.viewDidAppear)
        }
        .onDisappear {
            viewModel.sendAction(.viewDidDisappear)
        }
        .navigationTitle("\(viewModel.userId)")
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView(viewModel: .preview)
    }
}

private extension UserProfileView.ViewModel {
    static var preview: UserProfileView.ViewModel {
        return .init(
            exits: .init(
                onFinish: { _ in },
                onEditUser: { _ in }
            ),
            dependencies: .init(userId: "Some user!")
        )
    }
}
