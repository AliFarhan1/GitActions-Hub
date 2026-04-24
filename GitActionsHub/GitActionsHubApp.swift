import SwiftUI

@main
struct GitActionsHubApp: App {
    @StateObject private var gitHubService = GitHubService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gitHubService)
                .preferredColorScheme(.dark)
        }
    }
}