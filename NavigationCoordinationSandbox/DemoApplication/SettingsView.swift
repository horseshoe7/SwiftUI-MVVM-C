import SwiftUI

struct SettingsView: View {
    
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()
            
            VStack {
                Text("Settings View")
                    .navigationTitle("Settings")
                
                Button(
                    action: {
                        viewModel.sendAction(.didTapReset)
                    },
                    label: {
                        Text("Reset Stack")
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
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: .preview)
    }
}

private extension SettingsView.ViewModel {
    static var preview: SettingsView.ViewModel {
        return .init(
            exits: .init(
                onFinish: {
                    print("Preview: onFinish invoked.")
                },
                onReset: {
                    print("Preview: onReset invoked.")
                }
            )
        )
    }
}
