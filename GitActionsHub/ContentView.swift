import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if gitHubService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    ReposView()
                        .tabItem {
                            Label("Repos", systemImage: "folder.fill")
                        }
                        .tag(0)
                    
                    ActionsView()
                        .tabItem {
                            Label("Actions", systemImage: "bolt.fill")
                        }
                        .tag(1)
                }
                .tint(AppColors.accent)
            } else {
                LoginView()
            }
        }
        .onAppear {
            gitHubService.loadSavedToken()
            configureTabBarAppearance()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}