import SwiftUI

struct UnauthorizedView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            Color.red.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("Unauthorized!")
                Spacer()
                Button(
                    action: {
                        viewModel.sendAction(.tappedAuthenticate)
                    },
                    label: {
                        Text("Authenticate")
                    }
                )
                Spacer()
            }
        }
        .onAppear {
            viewModel.sendAction(.viewDidAppear)
        }
        .onDisappear {
            viewModel.sendAction(.viewDidDisappear)
        }
    }
}

struct UnauthorizedView_Previews: PreviewProvider {
    static var previews: some View {
        UnauthorizedView(viewModel: .preview)
    }
}

private extension UnauthorizedView.ViewModel {
    static var preview: UnauthorizedView.ViewModel {
        return .init(
            exits: .init(
                onTappedAuthorize: {}
            )
        )
    }
}
