import SwiftUI

struct FakeAuthFlowView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            Spacer()
            if viewModel.isSignInView {
                Text("Sign In")
            } else {
                Text("Sign Up")
            }
            
            Spacer()
            Button(action: {
                viewModel.sendAction(.tappedSuccess)
            }, label: {
                Text("Simulate Success")
            })
            Button(action: {
                viewModel.sendAction(.tappedFailed)
            }, label: {
                Text("Simulate Fail")
            })
            if viewModel.isSignInView {
                Button(action: {
                    viewModel.sendAction(.tappedSignUp)
                }, label: {
                    Text("Sign Up")
                })
            }
            Spacer()
        }
        .onAppear {
            viewModel.sendAction(.viewDidAppear)
        }
        .onDisappear {
            viewModel.sendAction(.viewDidDisappear)
        }
    }
}

struct FakeAuthFlowView_Previews: PreviewProvider {
    static var previews: some View {
        FakeAuthFlowView(viewModel: .preview)
    }
}

private extension FakeAuthFlowView.ViewModel {
    static var preview: FakeAuthFlowView.ViewModel {
        return .init(
            exits: .init(
                onFinish: { _ in },
                showSignUp: {}
            ),
            dependencies: .init(isSignInView: true)
        )
    }
}
