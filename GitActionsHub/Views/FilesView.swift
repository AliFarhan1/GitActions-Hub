import SwiftUI
import UniformTypeIdentifiers

// MARK: - Files View

struct FilesView: View {
    @StateObject private var fileManager = LocalFileManager()
    @EnvironmentObject var gitHubService: GitHubService

    @State private var showFileEditor    = false
    @State private var showCreateDialog  = false
    @State private var showCommitSheet   = false
    @State private var showImportPicker  = false
    @State private var showDeleteAlert   = false
    @State private var showRenameDialog  = false
    @State private var fileToDelete: GitFile?
    @State private var fileToRename: GitFile?
    @State private var newFileName       = ""
    @State private var isCreatingFolder  = false
    @State private var isEditMode        = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    header
                    pathBar
                    toolbar.padding(.horizontal).padding(.bottom, 8)

                    if fileManager.isLoading {
                        LoadingCard()
                    } else if fileManager.rootFiles.isEmpty {
                        EmptyStateView(
                            icon: "folder.badge.plus",
                            title: "مجلد فارغ",
                            subtitle: "أضف ملفات أو استورد من Files app"
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in
                                    FileRowView(
                                        file: file,
                                        depth: 0,
                                        isEditMode: isEditMode,
                                        canMoveUp: i > 0,
                                        canMoveDown: i < fileManager.rootFiles.count - 1,
                                        onTap:     { handleTap($0) },
                                        onDelete:  { fileToDelete = $0; showDeleteAlert  = true },
                                        onRename:  { fileToRename = $0; newFileName = $0.name; showRenameDialog = true },
                                        onMoveUp:  { fileManager.moveFile(file, direction: .up) },
                                        onMoveDown:{ fileManager.moveFile(file, direction: .down) }
                                    )
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        // sheets & alerts
        .sheet(isPresented: $showFileEditor) {
            if let f = fileManager.selectedFile {
                FileEditorView(file: f, content: fileManager.fileContent) { fileManager.writeFile(f, content: $0) }
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitPushSheet(gitHubService: gitHubService, fileManager: fileManager)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) {
            if case .success(let urls) = $0 { urls.forEach { fileManager.importFromFiles(url: $0) } }
        }
        .alert("إنشاء \(isCreatingFolder ? "مجلد" : "ملف")", isPresented: $showCreateDialog) {
            TextField("الاسم", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("إنشاء") {
                if !newFileName.isEmpty {
                    fileManager.createFile(name: newFileName, at: fileManager.currentPath.path, isDirectory: isCreatingFolder)
                    newFileName = ""
                }
            }
            Button("إلغاء", role: .cancel) { newFileName = "" }
        }
        .alert("إعادة تسمية", isPresented: $showRenameDialog) {
            TextField("الاسم الجديد", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("حفظ") {
                if let f = fileToRename, !newFileName.isEmpty { fileManager.renameFile(f, newName: newFileName); newFileName = "" }
            }
            Button("إلغاء", role: .cancel) { newFileName = "" }
        }
        .alert("حذف", isPresented: $showDeleteAlert) {
            Button("حذف", role: .destructive) { if let f = fileToDelete { fileManager.deleteFile(f) } }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("حذف \"\(fileToDelete?.name ?? "")\"؟") }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                Text("إدارة ملفات المشروع").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button { withAnimation { isEditMode.toggle() } } label: {
                Text(isEditMode ? "تم" : "ترتيب")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isEditMode ? Color(hex: "#6BCB77") : AppColors.textSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isEditMode ? Color(hex: "#6BCB77").opacity(0.15) : AppColors.surfaceElevated)
                    .clipShape(Capsule())
            }
            Button { showCommitSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Push").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                .background(LinearGradient(colors: [Color(hex: "#6BCB77"), Color(hex: "#4CAF50")], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6BCB77").opacity(0.4), radius: 8)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
    }

    // MARK: Path Bar
    private var pathBar: some View {
        HStack(spacing: 8) {
            if !fileManager.isAtRoot {
                Button { fileManager.navigateUp() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("رجوع").font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.accent.opacity(0.1)).clipShape(Capsule())
                }
            }
            Text(fileManager.currentPathDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(AppColors.surfaceElevated.opacity(0.5))
    }

    // MARK: Toolbar
    private var toolbar: some View {
        HStack(spacing: 8) {
            ToolbarButton(icon: "doc.badge.plus",          label: "ملف",      color: AppColors.accent)            { isCreatingFolder = false; newFileName = ""; showCreateDialog = true }
            ToolbarButton(icon: "folder.badge.plus",       label: "مجلد",     color: Color(hex: "#FFD93D"))        { isCreatingFolder = true;  newFileName = ""; showCreateDialog = true }
            ToolbarButton(icon: "square.and.arrow.down.fill", label: "استيراد", color: Color(hex: "#6BCB77"))     { showImportPicker = true }
            ToolbarButton(icon: "arrow.clockwise",         label: "تحديث",    color: AppColors.textSecondary)     { fileManager.loadFiles(at: fileManager.currentPath) }
        }
    }

    private func handleTap(_ file: GitFile) {
        if file.isDirectory {
            fileManager.loadFiles(at: URL(fileURLWithPath: file.path))
        } else {
            fileManager.readFile(file)
            showFileEditor = true
        }
    }
}

// MARK: - File Row

struct FileRowView: View {
    let file: GitFile
    let depth: Int
    let isEditMode: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onTap: (GitFile) -> Void
    let onDelete: (GitFile) -> Void
    let onRename: (GitFile) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 0) {
                // Move arrows
                if isEditMode {
                    VStack(spacing: 2) {
                        Button { onMoveUp() } label: {
                            Image(systemName: "chevron.up").font(.system(size: 11, weight: .bold))
                                .foregroundColor(canMoveUp ? AppColors.accent : AppColors.border)
                                .frame(width: 28, height: 22)
                        }.disabled(!canMoveUp)
                        Button { onMoveDown() } label: {
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                                .foregroundColor(canMoveDown ? AppColors.accent : AppColors.border)
                                .frame(width: 28, height: 22)
                        }.disabled(!canMoveDown)
                    }.padding(.leading, 4)
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if file.isDirectory { isExpanded.toggle() }
                        onTap(file)
                    }
                } label: {
                    HStack(spacing: 10) {
                        // Indent line
                        if depth > 0 {
                            Rectangle().fill(AppColors.border).frame(width: 1, height: 28)
                                .padding(.leading, CGFloat(depth) * 16)
                        }
                        // Arrow for folder
                        if file.isDirectory {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary).frame(width: 12)
                        } else {
                            Spacer().frame(width: 12)
                        }
                        // Icon
                        Image(systemName: file.icon).font(.system(size: 16))
                            .foregroundColor(file.iconColor).frame(width: 20)
                        // Name
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium,
                                          design: file.isDirectory ? .default : .monospaced))
                            .foregroundColor(AppColors.text)
                            .lineLimit(1)
                        Spacer()
                        // Size
                        if !file.isDirectory {
                            Text(formatSize(file.size))
                                .font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { onTap(file) } label: {
                        Label(file.isDirectory ? "فتح" : "تعديل", systemImage: "pencil")
                    }
                    Button { onRename(file) } label: {
                        Label("إعادة تسمية", systemImage: "pencil.circle")
                    }
                    Divider()
                    Button(role: .destructive) { onDelete(file) } label: {
                        Label("حذف", systemImage: "trash")
                    }
                }
            }
            .background(AppColors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Children
            if file.isDirectory && isExpanded, let children = file.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { i, child in
                    FileRowView(
                        file: child, depth: depth + 1, isEditMode: isEditMode,
                        canMoveUp: i > 0, canMoveDown: i < children.count - 1,
                        onTap: onTap, onDelete: onDelete, onRename: onRename,
                        onMoveUp: onMoveUp, onMoveDown: onMoveDown
                    )
                    .padding(.leading, 12)
                }
            }
        }
    }

    func formatSize(_ b: Int64) -> String {
        if b < 1024 { return "\(b)B" }
        if b < 1_048_576 { return "\(b/1024)KB" }
        return "\(b/1_048_576)MB"
    }
}

// MARK: - File Editor

struct FileEditorView: View {
    let file: GitFile
    let content: String
    let onSave: (String) -> Void

    @State private var text: String
    @State private var hasChanges = false
    @Environment(\.dismiss) var dismiss

    init(file: GitFile, content: String, onSave: @escaping (String) -> Void) {
        self.file = file; self.content = content; self.onSave = onSave
        _text = State(initialValue: content)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#080810").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top bar
                    HStack(spacing: 8) {
                        Image(systemName: file.icon).foregroundColor(file.iconColor)
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.text).lineLimit(1)
                        if hasChanges { Circle().fill(Color(hex: "#FFD93D")).frame(width: 6, height: 6) }
                        Spacer()
                        Text("\(text.components(separatedBy: "\n").count) سطر")
                            .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10).background(AppColors.surface)
                    Divider().background(AppColors.border)

                    // Code editor
                    HStack(alignment: .top, spacing: 0) {
                        // Line numbers
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(text.components(separatedBy: "\n").indices), id: \.self) { i in
                                Text("\(i + 1)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color(hex: "#444460"))
                                    .frame(minWidth: 44, alignment: .trailing)
                                    .padding(.vertical, 2)
                            }
                            Spacer()
                        }
                        .padding(.leading, 8).padding(.trailing, 12)
                        .background(Color(hex: "#0C0C18"))

                        Divider().background(AppColors.border)

                        TextEditor(text: Binding(
                            get: { text },
                            set: { text = $0; hasChanges = true }
                        ))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.text)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.leading, 8)
                    }
                    .background(Color(hex: "#080810"))
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSave(text); hasChanges = false; dismiss()
                    } label: {
                        Text("حفظ").font(.system(size: 14, weight: .bold))
                            .foregroundColor(hasChanges ? AppColors.accent : AppColors.textSecondary)
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Commit Push Sheet

struct CommitPushSheet: View {
    @ObservedObject var gitHubService: GitHubService
    @ObservedObject var fileManager: LocalFileManager

    @StateObject private var gitOps: GitOperationsManager
    @State private var commitMessage = ""
    @State private var selectedRepo  = ""
    @State private var branch        = "main"
    @State private var fileCount     = 0
    @Environment(\.dismiss) var dismiss

    init(gitHubService: GitHubService, fileManager: LocalFileManager) {
        self.gitHubService = gitHubService
        self.fileManager   = fileManager
        _gitOps = StateObject(wrappedValue: GitOperationsManager(gitHubService: gitHubService))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("Commit & Push").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                    Spacer()
                    if gitOps.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)).scaleEffect(0.8)
                    } else {
                        Spacer().frame(width: 22)
                    }
                }
                .padding()
                Divider().background(AppColors.border)

                ScrollView {
                    VStack(spacing: 16) {
                        // File count
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(AppColors.accent)
                            Text(fileCount > 0 ? "\(fileCount) ملف نصي سيُرفع" : "لا توجد ملفات نصية")
                                .font(.system(size: 13))
                                .foregroundColor(fileCount > 0 ? AppColors.text : Color(hex: "#FF6B6B"))
                            Spacer()
                        }
                        .padding(12)
                        .background((fileCount > 0 ? AppColors.accent : Color(hex: "#FF6B6B")).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder((fileCount > 0 ? AppColors.accent : Color(hex: "#FF6B6B")).opacity(0.25), lineWidth: 1))

                        // Commit message
                        VStack(alignment: .leading, spacing: 8) {
                            Label("رسالة Commit", systemImage: "text.bubble.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            TextField("fix: إصلاح...", text: $commitMessage, axis: .vertical)
                                .font(.system(size: 14)).foregroundColor(AppColors.text)
                                .padding(12).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                .lineLimit(3...6)
                        }

                        // Repo & Branch
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Repository", systemImage: "square.stack.3d.up.fill")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                Picker("", selection: $selectedRepo) {
                                    Text("اختر...").tag("")
                                    ForEach(gitHubService.repositories) { r in Text(r.name).tag(r.name) }
                                }
                                .pickerStyle(.menu).padding(10).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Branch", systemImage: "arrow.triangle.branch")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                TextField("main", text: $branch)
                                    .font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.text)
                                    .padding(10).background(AppColors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                    .frame(width: 100)
                            }
                        }

                        // Commit history
                        if !gitOps.commitHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("آخر Commits", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                ForEach(gitOps.commitHistory.prefix(3)) { c in
                                    HStack(spacing: 8) {
                                        Text(c.sha ?? "•••••••").font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.accent)
                                        Text(c.message).font(.system(size: 12)).foregroundColor(AppColors.text).lineLimit(1)
                                        Spacer()
                                        Text(c.branch).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(10).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        // Result
                        if let r = gitOps.lastCommitResult {
                            Text(r)
                                .font(.system(size: 13))
                                .foregroundColor(r.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B"))
                                .multilineTextAlignment(.center)
                                .padding(12).frame(maxWidth: .infinity)
                                .background((r.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B")).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                }

                // Push button
                Button { push() } label: {
                    HStack(spacing: 10) {
                        if gitOps.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 20))
                        }
                        Text(gitOps.isLoading ? "جارٍ الرفع..." : "Commit & Push")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient(
                        colors: canPush ? [Color(hex: "#6BCB77"), Color(hex: "#4CAF50")] : [AppColors.border, AppColors.border],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: canPush ? Color(hex: "#6BCB77").opacity(0.3) : .clear, radius: 10)
                }
                .disabled(!canPush || gitOps.isLoading).padding()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await gitHubService.fetchRepositories() }
            let files = fileManager.collectAllFiles(from: fileManager.rootFiles)
            fileCount = files.count
        }
    }

    var canPush: Bool { !commitMessage.isEmpty && !selectedRepo.isEmpty && fileCount > 0 }

    private func push() {
        guard let user = gitHubService.currentUser else { return }
        let files = fileManager.collectAllFiles(from: fileManager.rootFiles)
        fileCount = files.count
        guard !files.isEmpty else { gitOps.lastCommitResult = "❌ لا توجد ملفات نصية"; return }
        Task {
            _ = await gitOps.commitAndPush(
                owner: user.login, repo: selectedRepo,
                branch: branch, message: commitMessage, files: files
            )
            await MainActor.run { fileCount = fileManager.collectAllFiles(from: fileManager.rootFiles).count }
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 14))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(color).padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.12)).clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
        }
    }
}
