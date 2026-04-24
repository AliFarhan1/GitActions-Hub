import Foundation
import SwiftUI

class LocalFileManager: ObservableObject {
    static var appDocumentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    @Published var rootFiles: [GitFile] = []
    @Published var currentPathDisplay = "/"
    @Published var selectedFile: GitFile?
    @Published var fileContent = ""
    @Published var isLoading = false
    
    private var currentPath: URL = appDocumentsURL
    
    func loadFiles(at url: URL) {
        isLoading = true
        currentPath = url
        currentPathDisplay = url.path.replacingOccurrences(of: Self.appDocumentsURL.path, with: "/")
        if currentPathDisplay.isEmpty { currentPathDisplay = "/" }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var files: [GitFile] = []
            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            for item in contents {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)
                var size: Int64 = 0
                var date: Date?
                if !isDirectory.boolValue {
                    let attrs = try? fileManager.attributesOfItem(atPath: item.path)
                    size = attrs?[.size] as? Int64 ?? 0
                    date = attrs?[.modificationDate] as? Date
                }
                files.append(GitFile(
                    name: item.lastPathComponent,
                    path: item.path,
                    isDirectory: isDirectory.boolValue,
                    size: size,
                    modifiedDate: date
                ))
            }
            
            DispatchQueue.main.async {
                self.rootFiles = files.sorted { f1, f2 in
                    if f1.isDirectory != f2.isDirectory { return f1.isDirectory }
                    return f1.name.localizedCaseInsensitiveCompare(f2.name) == .orderedAscending
                }
                self.isLoading = false
            }
        }
    }
    
    func readFile(_ file: GitFile) {
        selectedFile = file
        if let data = FileManager.default.contents(atPath: file.path),
           let content = String(data: data, encoding: .utf8) {
            fileContent = content
        } else {
            fileContent = "[Binary file - cannot display]"
        }
    }
    
    func writeFile(_ file: GitFile, content: String) {
        try? content.write(toFile: file.path, atomically: true, encoding: .utf8)
    }
}