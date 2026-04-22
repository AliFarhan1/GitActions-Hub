import Foundation
import SwiftUI
import UniformTypeIdentifiers

class LocalFileManager: ObservableObject {
    @Published var rootFiles: [GitFile] = []
    @Published var currentPath: URL
    @Published var selectedFile: GitFile?
    @Published var fileContent: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let fm = FileManager.default
    
    // Text file extensions we can read/push
    static let textExtensions: Set<String> = [
        "swift", "m", "h", "mm", "c", "cpp", "cs",
        "txt", "md", "markdown", "json", "xml", "plist",
        "yaml", "yml", "sh", "bash", "zsh",
        "js", "ts", "html", "css", "py", "rb", "go",
        "gitignore", "gitkeep", "entitlements", "pbxproj",
        "strings", "stringsdict", "xcconfig", "podspec",
        "gradle", "kt", "java", "env", "toml", "ini", "cfg"
    ]
    
    static var appDocumentsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projects = docs.appendingPathComponent("Projects", isDirectory: true)
        if !FileManager.default.fileExists(atPath: projects.path) {
            try? FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        }
        return projects
    }
    
    init() {
        currentPath = LocalFileManager.appDocumentsURL
        createWelcomeFileIfNeeded()
        loadFiles(at: currentPath)
    }
    
    private func createWelcomeFileIfNeeded() {
        let readmePath = currentPath.appendingPathComponent("README.txt")
        if !fm.fileExists(atPath: readmePath.path) {
            let content = """
GitActions Hub - مجلد المشاريع
================================
ضع ملفات مشاريعك هنا لتتمكن من:
- تعديلها من داخل التطبيق
- رفعها على GitHub عبر Commit & Push

مسار المجلد في Files:
Files > On My iPhone > GitActionsHub > Projects
"""
            try? content.write(to: readmePath, atomically: true, encoding: .utf8)
        }
    }
    
    func loadFiles(at url: URL) {
        isLoading = true
        currentPath = url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let files = self.buildFileTree(at: url)
            DispatchQueue.main.async { self.rootFiles = files; self.isLoading = false }
        }
    }
    
    private func buildFileTree(at url: URL) -> [GitFile] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return contents.compactMap { fileURL in
            let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            let isDir = res?.isDirectory ?? false
            var file = GitFile(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDir,
                size: Int64(res?.fileSize ?? 0),
                modifiedDate: res?.contentModificationDate ?? Date()
            )
            if isDir { file.children = buildFileTree(at: fileURL) }
            return file
        }.sorted { a, b in a.isDirectory != b.isDirectory ? a.isDirectory : a.name < b.name }
    }
    
    // Fix: Only collect readable text files, skip binary
    func collectAllFiles(from files: [GitFile], basePath: String = "") -> [(path: String, content: String)] {
        var result: [(path: String, content: String)] = []
        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            if file.isDirectory {
                let children: [GitFile]
                if let loaded = file.children, !loaded.isEmpty {
                    children = loaded
                } else {
                    children = buildFileTree(at: URL(fileURLWithPath: file.path))
                }
                let subFiles = collectAllFiles(from: children, basePath: relativePath)
                result.append(contentsOf: subFiles)
            } else {
                // Fix: Check extension before reading
                let ext = (file.name as NSString).pathExtension.lowercased()
                let noExt = ext.isEmpty // files without extension like .gitkeep, .gitignore
                
                let isTextFile = LocalFileManager.textExtensions.contains(ext) || noExt || file.name.hasPrefix(".")
                
                guard isTextFile else { continue } // Skip binary files (png, ipa, etc.)
                
                // Fix: Guard against large files (>2MB)
                guard file.size < 2_000_000 else { continue }
                
                let url = URL(fileURLWithPath: file.path)
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    result.append((path: relativePath, content: content))
                } else if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                    result.append((path: relativePath, content: content))
                }
                // Silently skip unreadable files
            }
        }
        return result
    }
    
    func isTextFile(_ file: GitFile) -> Bool {
        let ext = (file.name as NSString).pathExtension.lowercased()
        return LocalFileManager.textExtensions.contains(ext) || ext.isEmpty
    }
    
    func readFile(_ file: GitFile) {
        guard !file.isDirectory else { return }
        let url = URL(fileURLWithPath: file.path)
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            DispatchQueue.main.async { self.fileContent = content; self.selectedFile = file }
        } else if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
            DispatchQueue.main.async { self.fileContent = content; self.selectedFile = file }
        } else {
            DispatchQueue.main.async {
                self.error = "لا يمكن فتح ملفات ثنائية (binary)"
            }
        }
    }
    
    func writeFile(_ file: GitFile, content: String) {
        let url = URL(fileURLWithPath: file.path)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر حفظ الملف: \(error.localizedDescription)" }
    }
    
    func createFile(name: String, at parentPath: String, isDirectory: Bool = false) {
        let url = URL(fileURLWithPath: "\(parentPath)/\(name)")
        do {
            if isDirectory {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                let gitkeep = url.appendingPathComponent(".gitkeep")
                fm.createFile(atPath: gitkeep.path, contents: Data())
            } else {
                fm.createFile(atPath: url.path, contents: Data())
            }
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الإنشاء: \(error.localizedDescription)" }
    }
    
    func deleteFile(_ file: GitFile) {
        do {
            try fm.removeItem(at: URL(fileURLWithPath: file.path))
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الحذف: \(error.localizedDescription)" }
    }
    
    func renameFile(_ file: GitFile, newName: String) {
        let oldURL = URL(fileURLWithPath: file.path)
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fm.moveItem(at: oldURL, to: newURL)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر إعادة التسمية: \(error.localizedDescription)" }
    }
    
    func moveFile(_ file: GitFile, direction: MoveDirection) {
        guard let index = rootFiles.firstIndex(where: { $0.id == file.id }) else { return }
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0 && newIndex < rootFiles.count else { return }
        rootFiles.swapAt(index, newIndex)
    }
    
    func importFromFiles(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let destURL = currentPath.appendingPathComponent(url.lastPathComponent)
        do {
            if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
            try fm.copyItem(at: url, to: destURL)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الاستيراد: \(error.localizedDescription)" }
    }
    
    func navigateUp() {
        let parent = currentPath.deletingLastPathComponent()
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        if currentPath.path != docs.path { loadFiles(at: parent) }
    }
    
    var isAtRoot: Bool { currentPath == LocalFileManager.appDocumentsURL }
    
    var currentPathDisplay: String {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.path
        return currentPath.path.replacingOccurrences(of: docs, with: "📱 iPhone")
    }
}

enum MoveDirection { case up, down }

// MARK: - Git Operations Manager

class GitOperationsManager: ObservableObject {
    @Published var commitHistory: [CommitInfo] = []
    @Published var isLoading = false
    @Published var lastCommitResult: String?
    
    private let gitHubService: GitHubService
    init(gitHubService: GitHubService) { self.gitHubService = gitHubService }
    
    func commitAndPush(owner: String, repo: String, branch: String, message: String, files: [(path: String, content: String)]) async -> Bool {
        await MainActor.run { isLoading = true }
        
        guard !files.isEmpty else {
            await MainActor.run { self.lastCommitResult = "❌ لا توجد ملفات نصية للرفع"; self.isLoading = false }
            return false
        }
        
        do {
            guard let token = UserDefaults.standard.string(forKey: "gh_access_token"),
                  let baseURL = URL(string: "https://api.github.com") else { return false }
            
            func makeReq(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
                var req = URLRequest(url: baseURL.appendingPathComponent(path))
                req.httpMethod = method
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body
                return req
            }
            
            // 1. Get SHA
            struct RefResp: Codable { struct Obj: Codable { let sha: String }; let object: Obj }
            let (refData, _) = try await URLSession.shared.data(for: makeReq("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)"))
            let currentSHA = try JSONDecoder().decode(RefResp.self, from: refData).object.sha
            
            // 2. Create blobs
            struct BlobResp: Codable { let sha: String }
            var treeItems: [[String: String]] = []
            for file in files {
                let bodyData = try JSONEncoder().encode(["content": file.content, "encoding": "utf-8"])
                var req = makeReq("/repos/\(owner)/\(repo)/git/blobs", method: "POST", body: bodyData)
                let (blobData, _) = try await URLSession.shared.data(for: req)
                let blobSHA = try JSONDecoder().decode(BlobResp.self, from: blobData).sha
                treeItems.append(["path": file.path, "mode": "100644", "type": "blob", "sha": blobSHA])
            }
            
            // 3. Create tree
            struct TreeResp: Codable { let sha: String }
            let treeBody = try JSONSerialization.data(withJSONObject: ["base_tree": currentSHA, "tree": treeItems])
            let (treeData, _) = try await URLSession.shared.data(for: makeReq("/repos/\(owner)/\(repo)/git/trees", method: "POST", body: treeBody))
            let treeSHA = try JSONDecoder().decode(TreeResp.self, from: treeData).sha
            
            // 4. Create commit
            struct CommitResp: Codable { let sha: String }
            let commitBody = try JSONSerialization.data(withJSONObject: ["message": message, "tree": treeSHA, "parents": [currentSHA]])
            let (commitData, _) = try await URLSession.shared.data(for: makeReq("/repos/\(owner)/\(repo)/git/commits", method: "POST", body: commitBody))
            let commitSHA = try JSONDecoder().decode(CommitResp.self, from: commitData).sha
            
            // 5. Update ref
            let updateBody = try JSONSerialization.data(withJSONObject: ["sha": commitSHA, "force": false])
            let _ = try await URLSession.shared.data(for: makeReq("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)", method: "PATCH", body: updateBody))
            
            await MainActor.run {
                self.commitHistory.insert(
                    CommitInfo(message: message, files: files.map { $0.path }, branch: branch, timestamp: Date(), sha: String(commitSHA.prefix(7))),
                    at: 0
                )
                self.lastCommitResult = "✅ تم Push بنجاح!\nSHA: \(String(commitSHA.prefix(7))) · \(files.count) ملف"
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run { self.lastCommitResult = "❌ فشل: \(error.localizedDescription)"; self.isLoading = false }
            return false
        }
    }
}
