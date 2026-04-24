import Foundation
import SwiftUI

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let avatarUrl: String?
    let name: String?
    let bio: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, bio
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let cloneUrl: String
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let isPrivate: Bool
    let defaultBranch: String
    let updatedAt: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let headBranch: String
    let headCommit: HeadCommit
    let status: String
    let conclusion: String?
    let createdAt: Date
    let updatedAt: Date
    let runNumber: Int
    let event: String
    let actor: Actor?
    let workflowId: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event, actor
        case headBranch = "head_branch"
        case headCommit = "head_commit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runNumber = "run_number"
        case workflowId = "workflow_id"
    }
    
    struct HeadCommit: Codable {
        let id: String
        let message: String
        let author: Author
        
        enum CodingKeys: String, CodingKey {
            case id, message, author
        }
        
        struct Author: Codable {
            let name: String
            let email: String
        }
    }
    
    struct Actor: Codable {
        let id: Int
        let login: String
        let avatarUrl: String?
        
        enum CodingKeys: String, CodingKey {
            case id, login
            case avatarUrl = "avatar_url"
        }
    }
}

struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: Date?
    let completedAt: Date?
    let htmlUrl: String
    let steps: [Step]
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, steps
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case htmlUrl = "html_url"
    }
    
    struct Step: Codable, Identifiable {
        let id: Int
        let name: String
        let status: String
        let conclusion: String?
        let number: Int
        let startedAt: String?
        
        enum CodingKeys: String, CodingKey {
            case id, name, status, conclusion, number
            case startedAt = "started_at"
        }
    }
}

struct BuildLog: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let content: String
    let type: LogLineType
    
    enum LogLineType {
        case normal, error, warning, success, command, info
    }
}

struct Workflow: Codable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let state: String
}

struct GitFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?
    
    var icon: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json", "xml", "yml", "yaml": return "doc.text"
        case "html", "css", "scss": return "globe"
        case "md", "txt", "doc": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        default: return "doc"
        }
    }
    
    var iconColor: Color {
        if isDirectory { return Color(hex: "#FFD93D") }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return Color(hex: "#F05138")
        case "js", "ts": return Color(hex: "#F7DF1E")
        case "json", "xml", "yml": return Color(hex: "#6BCB77")
        case "md", "txt": return Color(hex: "#C77DFF")
        case "png", "jpg", "gif": return Color(hex: "#FF6B6B")
        default: return AppColors.textSecondary
        }
    }
}

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}