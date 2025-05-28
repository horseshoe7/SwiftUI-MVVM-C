import SwiftUI

struct HomeScreenView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            Text("HomeScreenView")
            
            Button("Go to Profile") {
                viewModel.sendAction(.didTapShowProfile)
            }
            
            Button("Show Settings") {
                viewModel.sendAction(.didTapShowSettings)
            }
            
//            Button("Show Auth") {
//                viewModel.sendAction(.didTapAuth)
//            }
        }
        .onAppear {
            viewModel.sendAction(.viewDidAppear)
        }
        .onDisappear {
            viewModel.sendAction(.viewDidDisappear)
        }
        .navigationTitle("Home")
    }
}

struct HomeScreenView_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreenView(viewModel: .preview)
    }
}

private extension HomeScreenView.ViewModel {
    static var preview: HomeScreenView.ViewModel {
        return .init(
            exits: .init(
                onShowProfile: { _ in },
                onShowSettings: { },
                onShowAuth: { }
            )
        )
    }
}
