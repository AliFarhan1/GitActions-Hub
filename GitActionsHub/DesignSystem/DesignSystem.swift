import SwiftUI

struct AppColors {
    static let background = Color(hex: "#0D1117")
    static let surface = Color(hex: "#161B22")
    static let surfaceElevated = Color(hex: "#21262D")
    static let accent = Color(hex: "#58A6FF")
    static let text = Color.white
    static let textSecondary = Color(hex: "#8B949E")
    static let border = Color(hex: "#30363D")
}

struct AnimatedGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        LinearGradient(
            colors: [AppColors.background, AppColors.surface, Color(hex: "#1a1f2e")],
            startPoint: animate ? .topLeading : .bottomLeading,
            endPoint: animate ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(AppColors.textSecondary)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.text)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct FileEditorView: View {
    let file: GitFile
    @Binding var content: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var editedContent: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    TextEditor(text: $editedContent)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppColors.text)
                        .scrollContentBackground(.hidden)
                        .background(AppColors.surfaceElevated)
                        .padding()
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editedContent)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { editedContent = content }
    }
}