import SwiftUI

struct LoginView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var token = ""
    @State private var showTokenInput = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [AppColors.accent, Color(hex: "#C77DFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 8) {
                    Text("GitActionsHub")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(AppColors.text)
                    Text("Manage GitHub Actions")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if showTokenInput { tokenInputView } else { mainButtons }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .sheet(isPresented: $showTokenInput, content: { tokenSheet })
    }
    
    var mainButtons: some View {
        VStack(spacing: 16) {
            Button {
                if let url = URL(string: "https://github.com/settings/tokens/new?scopes=repo,workflow&description=GitActionsHub") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Get Personal Access Token")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                showTokenInput = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                    Text("Enter Token Manually")
                    Spacer()
                    Image(systemName: "keyboard")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding()
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    var tokenInputView: some View {
        VStack(spacing: 16) {
            TextField("ghp_xxxxxxxxxxxx", text: $token)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppColors.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(AppColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button {
                Task { await gitHubService.authenticateWithOAuth(token: token) }
                showTokenInput = false
            } label: {
                Text("Login")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                showTokenInput = false
                token = ""
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    var tokenSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Enter GitHub Personal Access Token")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Text("Token requires: repo, workflow scopes")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    TextField("ghp_xxxxxxxxxxxx", text: $token)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppColors.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button {
                        Task { await gitHubService.authenticateWithOAuth(token: token) }
                        showTokenInput = false
                    } label: {
                        Text("Login")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .preferredColorScheme(.dark)
        }
    }
}