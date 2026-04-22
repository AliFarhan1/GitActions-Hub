import SwiftUI

// MARK: - GitFile
struct GitFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let isTextFile: Bool
    let isBinaryFile: Bool
    let content: String?
}

// MARK: - FileToPush
struct FileToPush: Identifiable {
    let id = UUID()
    let path: String
    let content: String
    let isBinary: Bool
    let size: Int64
}

// MARK: - Repo (GitHubRepo alias)
struct Repo: Codable, Identifiable {
    let id: Int
    let name: String
    let full_name: String
    let owner: RepoOwner
    let html_url: String
    let description: String?
    let private_field: Bool?
    let default_branch: String?
    let size: Int?
    let language: String?
    let updated_at: String?
    let fork: Bool?
    let stargazers_count: Int?
    let forks_count: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, full_name, owner, html_url, description, size, language, updated_at
        case private_field = "private"
        case default_branch, fork, stargazers_count, forks_count
    }
    
    var isPrivate: Bool { private_field ?? false }
    
    // ✅ Aliases تستخدمها Views
    var fullName: String { full_name }
    var stargazersCount: Int { stargazers_count ?? 0 }
    var forksCount: Int { forks_count ?? 0 }
}

typealias GitHubRepo = Repo

// MARK: - RepoOwner
struct RepoOwner: Codable {
    let login: String
    let avatar_url: String?
    let id: Int?
}

// MARK: - GitHubUser
struct GitHubUser: Codable {
    let login: String
    let id: Int
    let avatar_url: String?
    let name: String?
    let bio: String?
    let public_repos: Int?
    let followers: Int?
    let following: Int?
    let html_url: String?
}

// MARK: - WorkflowRun
struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let head_branch: String
    let status: String
    let conclusion: String?
    let created_at: String
    let updated_at: String
    let html_url: String
    let head_sha: String?
    let event: String?
    
    var displayStatus: String {
        switch status {
        case "queued": return "⏳"
        case "in_progress": return "🔄"
        case "completed": return "✅"
        default: return status
        }
    }
    
    var displayConclusion: String {
        switch conclusion {
        case "success": return "✅"
        case "failure": return "❌"
        case "cancelled": return "🚫"
        default: return conclusion ?? ""
        }
    }
    
    var isRunning: Bool {
        status == "in_progress" || status == "queued" || status == "waiting"
    }
    
    // ✅ statusColor
    var statusColor: Color {
        switch status {
        case "completed":
            return conclusion == "success" ? Color(hex: "6BCB77") : Color(hex: "FF6B6B")
        case "in_progress": return Color(hex: "6C63FF")
        case "queued": return Color(hex: "FFD93D")
        default: return Color(hex: "8888A0")
        }
    }
    
    // ✅ statusIcon
    var statusIcon: String {
        switch status {
        case "completed":
            return conclusion == "success" ? "checkmark.circle.fill" : "xmark.circle.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        case "queued": return "clock.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - WorkflowRunsResponse
struct WorkflowRunsResponse: Codable {
    let total_count: Int
    let workflow_runs: [WorkflowRun]
}

// MARK: - WorkflowJob
struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let started_at: String?
    let completed_at: String?
    let steps: [WorkflowStep]?
}

// MARK: - WorkflowStep
struct WorkflowStep: Codable, Identifiable {
    let number: Int
    let name: String
    let status: String
    let conclusion: String?
    let started_at: String?
    let completed_at: String?
    var id: Int { number }
}

// MARK: - WorkflowJobsResponse
struct WorkflowJobsResponse: Codable {
    let total_count: Int
    let jobs: [WorkflowJob]
}

// MARK: - BuildLog
struct BuildLog: Identifiable {
    let id: Int
    let lineNumber: Int
    let text: String
    let timestamp: String?
    
    enum LogLineType {
        case error
        case warning
        case command
        case normal
    }
    
    // ✅ type — تستخدمها ActionsView
    var type: LogLineType {
        if text.contains("error:") || text.contains("Error:") || text.contains("ERROR:") { return .error }
        if text.contains("warning:") || text.contains("Warning:") || text.contains("WARN:") { return .warning }
        if text.hasPrefix("$") || text.hasPrefix("+ ") { return .command }
        return .normal
    }
    
    // ✅ content — تستخدمها ActionsView
    var content: String { text }
}

// MARK: - GitHubContent
struct GitHubContent: Codable {
    let name: String
    let path: String
    let sha: String?
    let type: String
    let content: String?
    let encoding: String?
    let size: Int?
}

// MARK: - LogLine
struct LogLine: Identifiable {
    let id: Int
    let text: String
    var isError: Bool { text.contains("error:") || text.contains("Error:") }
    var isWarning: Bool { text.contains("warning:") || text.contains("Warning:") }
    var isCommand: Bool { text.hasPrefix("$") || text.hasPrefix("+ ") }
}
