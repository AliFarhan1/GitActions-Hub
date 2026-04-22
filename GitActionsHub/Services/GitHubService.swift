import Foundation
import SwiftUI

class GitHubService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var repos: [Repo] = []
    @Published var workflowRuns: [WorkflowRun] = []
    @Published var logLines: [LogLine] = []
    @Published var error: String?
    @Published var isLoading = false
    @Published var lastCommitResult: String?
    
    // ✅ خصائص مفقودة تستخدمها Views القديمة
    @Published var currentUser: GitHubUser?
    @Published var isAuthenticated: Bool = false
    
    // ✅ حالة الرفع
    @Published var isPushing = false
    @Published var pushProgress: String = ""
    @Published var pushFileIndex: Int = 0
    @Published var pushFileTotal: Int = 0
    
    private let baseURL = "https://api.github.com"
    
    // MARK: - Token Management
    private var _token: String {
        UserDefaults.standard.string(forKey: "gh_access_token") ?? ""
    }
    
    var token: String { _token }
    
    var username: String {
        UserDefaults.standard.string(forKey: "gh_username") ?? ""
    }
    
    // ✅ Alias للخصائص — تستخدمها Views القديمة
    var repositories: [GitHubRepo] { repos }
    
    // MARK: - Generic Request Helper
    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = URL(string: "\(baseURL)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body { req.httpBody = body }
        return req
    }
    
    // MARK: - ✅ loadSavedToken — تستخدمها ContentView
    func loadSavedToken() {
        let savedToken = UserDefaults.standard.string(forKey: "gh_access_token")
        if let token = savedToken, !token.isEmpty {
            isAuthenticated = true
            // تحميل بيانات المستخدم المحفوظة
            loadSavedUser()
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func loadSavedUser() {
        guard let userData = UserDefaults.standard.data(forKey: "gh_user_data") else { return }
        currentUser = try? JSONDecoder().decode(GitHubUser.self, from: userData)
    }
    
    private func saveUser(_ user: GitHubUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "gh_user_data")
        }
        UserDefaults.standard.set(user.login, forKey: "gh_username")
    }
    
    // MARK: - ✅ authenticateWithOAuth — تستخدمها LoginView
    func authenticateWithOAuth(token: String) async {
        guard !token.isEmpty else {
            await MainActor.run { self.error = "❌ التوكن فارغ" }
            return
        }
        
        // حفظ التوكن
        UserDefaults.standard.set(token, forKey: "gh_access_token")
        
        // التحقق من التوكن وجلب بيانات المستخدم
        var req = URLRequest(url: URL(string: "\(baseURL)/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { self.error = "❌ استجابة غير صالحة" }
                return
            }
            
            if httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(GitHubUser.self, from: data)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.error = nil
                }
                saveUser(user)
            } else {
                // التوكن غير صالح
                UserDefaults.standard.removeObject(forKey: "gh_access_token")
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.error = "❌ التوكن غير صالح"
                }
            }
        } catch {
            await MainActor.run {
                self.error = "❌ فشل الاتصال: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - ✅ logout — تستخدمها ReposView
    func logout() {
        UserDefaults.standard.removeObject(forKey: "gh_access_token")
        UserDefaults.standard.removeObject(forKey: "gh_user_data")
        UserDefaults.standard.removeObject(forKey: "gh_username")
        currentUser = nil
        isAuthenticated = false
        repos = []
        workflowRuns = []
        logLines = []
        error = nil
    }
    
    // MARK: - Token Validation
    func validateToken(_ token: String) async -> Bool {
        var req = URLRequest(url: URL(string: "\(baseURL)/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(GitHubUser.self, from: data)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
                saveUser(user)
                return true
            }
        } catch {}
        return false
    }
    
    // MARK: - ✅ fetchRepositories — Alias تستخدمها Views القديمة
    func fetchRepositories() async {
        await fetchRepos()
    }
    
    // MARK: - Fetch Repos
    func fetchRepos() async {
        await MainActor.run { isLoading = true; error = nil }
        
        var allRepos: [Repo] = []
        var page = 1
        
        repeat {
            let req = makeRequest("/user/repos?sort=updated&per_page=100&page=\(page)")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let httpResponse = response as? HTTPURLResponse else { break }
                
                if httpResponse.statusCode == 401 {
                    await MainActor.run { error = "❌ التوكن غير صالح — سجّل الدخول مجدداً"; isLoading = false }
                    return
                }
                
                let pageRepos = try JSONDecoder().decode([Repo].self, from: data)
                allRepos.append(contentsOf: pageRepos)
                
                if pageRepos.count < 100 { break }
                page += 1
            } catch {
                await MainActor.run { self.error = "تعذّر جلب المستودعات: \(error.localizedDescription)"; isLoading = false }
                return
            }
        } while true
        
        await MainActor.run {
            self.repos = allRepos
            self.isLoading = false
        }
    }
    
    // MARK: - Fetch Workflow Runs
    func fetchWorkflowRuns(owner: String, repo: String) async {
        await MainActor.run { isLoading = true; error = nil }
        
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs?per_page=50")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                await MainActor.run { error = "❌ المستودع غير موجود أو ليس لديك صلاحية"; isLoading = false }
                return
            }
            
            let result = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
            await MainActor.run { workflowRuns = result.workflow_runs; isLoading = false }
        } catch {
            await MainActor.run { self.error = "تعذّر جلب الأكشنز: \(error.localizedDescription)"; isLoading = false }
        }
    }
    
    // MARK: - Fetch Build Logs
    func fetchLogs(owner: String, repo: String, runId: Int) async {
        await MainActor.run { isLoading = true; logLines = []; error = nil }
        
        let jobsReq = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (jobsData, _) = try await URLSession.shared.data(for: jobsReq)
            guard let jobsJson = try? JSONSerialization.jsonObject(with: jobsData) as? [String: Any],
                  let jobs = jobsJson["jobs"] as? [[String: Any]],
                  let firstJob = jobs.first,
                  let jobId = firstJob["id"] as? Int else {
                await MainActor.run { error = "❌ لا توجد مهام"; isLoading = false }
                return
            }
            
            let logsReq = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs")
            let (logsData, _) = try await URLSession.shared.data(for: logsReq)
            
            guard let logText = String(data: logsData, encoding: .utf8) else {
                await MainActor.run { error = "❌ تعذّر قراءة السجلات"; isLoading = false }
                return
            }
            
            let lines = logText.components(separatedBy: "\n")
            let logLines = lines.enumerated().map { index, line in
                LogLine(id: index + 1, text: line)
            }
            
            await MainActor.run { self.logLines = logLines; isLoading = false }
            
        } catch {
            await MainActor.run { self.error = "تعذّر جلب السجلات: \(error.localizedDescription)"; isLoading = false }
        }
    }
    
    // MARK: - Fetch Jobs for a Run ✅
    func fetchJobs(owner: String, repo: String, runId: Int) async -> [WorkflowJob] {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }
            let result = try JSONDecoder().decode(WorkflowJobsResponse.self, from: data)
            return result.jobs
        } catch {
            return []
        }
    }
    
    // MARK: - Fetch Job Logs ✅
    func fetchJobLogs(owner: String, repo: String, jobId: Int) async -> [BuildLog] {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let logText = String(data: data, encoding: .utf8) else { return [] }
            
            let lines = logText.components(separatedBy: "\n")
            return lines.enumerated().map { index, line in
                BuildLog(id: index, lineNumber: index + 1, text: line, timestamp: nil)
            }
        } catch {
            return []
        }
    }
    
    // MARK: - ✅ رفع الملفات — Contents API
    func pushFiles(
        owner: String,
        repo: String,
        branch: String,
        message: String,
        files: [FileToPush],
        fileManager: LocalFileManager
    ) async -> Bool {
        await MainActor.run {
            isPushing = true
            pushFileIndex = 0
            pushFileTotal = files.count
            pushProgress = "جارٍ الرفع..."
            lastCommitResult = nil
            error = nil
        }
        
        guard !token.isEmpty else {
            await MainActor.run {
                error = "❌ لم يتم العثور على التوكن"
                isPushing = false
            }
            return false
        }
        
        guard !files.isEmpty else {
            await MainActor.run {
                lastCommitResult = "⚠️ لا توجد ملفات للرفع"
                isPushing = false
            }
            return false
        }
        
        var successCount = 0
        var failCount = 0
        var failedFiles: [String] = []
        
        for (index, file) in files.enumerated() {
            await MainActor.run {
                pushFileIndex = index + 1
                pushProgress = "رفع \(index + 1)/\(files.count): \(file.path)"
            }
            
            let success = await uploadSingleFile(
                owner: owner,
                repo: repo,
                branch: branch,
                message: "\(message) — \(file.path
