import SwiftUI

struct EditUserView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            Text("EditUserView")
            Text("Editing UserID: \(viewModel.userId)")
            
            Button(
                action: {
                    viewModel.sendAction(.didPressSave)
                },
                label: {
                    Text("Save and Exit Flow")
                }
            )
        }
        .onAppear {
            viewModel.sendAction(.viewDidAppear)
        }
        .onDisappear {
            viewModel.sendAction(.viewDidDisappear)
        }
        .navigationTitle("Edit \(viewModel.userId)")
    }
}

struct EditUserView_Previews: PreviewProvider {
    static var previews: some View {
        EditUserView(viewModel: .preview)
    }
}

private extension EditUserView.ViewModel {
    static var preview: EditUserView.ViewModel {
        return .init(
            exits: .init(
                onFinish: { _ in },
                onSavedUser: { _ in }
            ),
            dependencies: .init(userId: "Some User!")
        
        )
    }
}
