import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var showingLogoutConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let user = gitHubService.currentUser {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Avatar
                            AsyncImage(url: URL(string: user.avatar_url ?? "")) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            
                            // Username
                            Text(user.login)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            if let name = user.name {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let bio = user.bio {
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Stats
                            HStack(spacing: 30) {
                                statItem(value: "\(user.public_repos ?? 0)", label: "مستودعات")
                                statItem(value: "\(user.followers ?? 0)", label: "متابعين")
                                statItem(value: "\(user.following ?? 0)", label: "يتابع")
                            }
                            .padding()
                            .background(Color(hex: "1A1A25"))
                            .cornerRadius(16)
                            
                            // Token info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(AppColors.accent)
                                    Text("التوكن")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(gitHubService.isAuthenticated ? "✅ نشط" : "❌ غير نشط")
                                        .font(.caption)
                                        .foregroundColor(gitHubService.isAuthenticated ? .green : .red)
                                }
                                
                                Text("@\(gitHubService.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(hex: "1A1A25"))
                            .cornerRadius(12)
                            
                            // Logout
                            Button(role: .destructive) {
                                showingLogoutConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right.square.fill")
                                    Text("تسجيل الخروج")
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("لم يتم تسجيل الدخول")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("👤 الملف الشخصي")
            .navigationBarTitleDisplayMode(.inline)
            .alert("تسجيل الخروج", isPresented: $showingLogoutConfirm) {
                Button("إلغاء", role: .cancel) {}
                Button("خروج", role: .destructive) {
                    gitHubService.logout()
                }
            } message: {
                Text("هل تريد تسجيل الخروج؟")
            }
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}