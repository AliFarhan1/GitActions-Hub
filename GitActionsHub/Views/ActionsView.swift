import SwiftUI

struct ActionsView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedRepo: GitHubRepo?
    @State private var isLoadingRuns = false
    @State private var autoRefreshTimer: Timer?
    @State private var searchText = ""
    @State private var selectedRun: WorkflowRun?
    @State private var showingRunDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if gitHubService.isLoading && workflowRuns.isEmpty {
                        loadingView
                    } else if selectedRepo == nil {
                        repoPicker
                    } else {
                        runsList
                    }
                }
            }
            .navigationTitle("⚡ الأكشنز")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if selectedRepo != nil {
                        Button {
                            selectedRepo = nil
                            stopAutoRefresh()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                    Button {
                        Task { await loadRuns(for: selectedRepo) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingRunDetail) {
                if let run = selectedRun {
                    RunDetailView(run: run)
                }
            }
        }
        .onAppear {
            if gitHubService.repositories.isEmpty {
                Task { await gitHubService.fetchRepositories() }
            }
        }
        .onDisappear { stopAutoRefresh() }
    }

    private var workflowRuns: [WorkflowRun] {
        gitHubService.workflowRuns
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text("جارٍ التحميل...")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Repo Picker
    private var repoPicker: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accent)
            Text("اختر مستودعاً")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("اختر مستودعاً لعرض الـ Actions")
                .foregroundColor(.secondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredRepos) { repo in
                        Button {
                            selectedRepo = repo
                            Task { await loadRuns(for: repo) }
                            startAutoRefresh(for: repo)
                        } label: {
                            repoRow(repo)
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "بحث عن مستودع...")
        }
        .padding()
    }

    private var filteredRepos: [GitHubRepo] {
        let repos = gitHubService.repositories
        if searchText.isEmpty { return repos }
        return repos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func repoRow(_ repo: GitHubRepo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "repo")
                .foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.fullName)
                    .font(.body)
                    .foregroundColor(.white)
                if let desc = repo.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if repo.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(12)
    }

    // MARK: - Runs List
    private var runsList: some View {
        VStack(spacing: 0) {
            // Repo info
            HStack {
                Image(systemName: "repo")
                    .foregroundColor(AppColors.accent)
                Text(selectedRepo?.fullName ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(hex: "12121A"))

            if workflowRuns.isEmpty {
                emptyRunsView
            } else {
                List {
                    ForEach(workflowRuns) { run in
                        Button {
                            selectedRun = run
                            showingRunDetail = true
                        } label: {
                            runRow(run)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyRunsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("لا توجد أكشنز")
                .font(.title3)
                .foregroundColor(.white)
            Text("لم يتم تشغيل أي workflow بعد")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func runRow(_ run: WorkflowRun) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: run.statusIcon)
                .font(.title3)
                .foregroundColor(run.statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(run.name)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(run.head_branch)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "2A2A3A"))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)

                    Text(run.event ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(run.displayConclusion)
                    .font(.caption)

                if run.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(run.statusColor.opacity(0.08))
        )
    }

    // MARK: - Functions
    private func loadRuns(for repo: GitHubRepo?) {
        guard let repo = repo else { return }
        guard let user = gitHubService.currentUser else { return }
        Task {
            await gitHubService.fetchWorkflowRuns(owner: user.login, repo: repo.name)
        }
    }

    private func startAutoRefresh(for repo: GitHubRepo) {
        stopAutoRefresh()
        guard let user = gitHubService.currentUser else { return }
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await gitHubService.fetchWorkflowRuns(owner: user.login, repo: repo.name)
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
}

// MARK: - Run Detail View
struct RunDetailView: View {
    @EnvironmentObject var gitHubService: GitHubService
    let run: WorkflowRun
    @State private var jobs: [WorkflowJob] = []
    @State private var selectedJob: WorkflowJob?
    @State private var showingLogs = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Run info card
                        runInfoCard

                        // Jobs
                        if jobs.isEmpty {
                            ProgressView()
                                .tint(.white)
                        } else {
                            ForEach(jobs) { job in
                                Button {
                                    selectedJob = job
                                    showingLogs = true
                                } label: {
                                    jobRow(job)
                                }
                            }
                        }

                        // Actions
                        HStack(spacing: 16) {
                            if run.isRunning {
                                Button {
                                    cancelRun()
                                } label: {
                                    Label("إلغاء", systemImage: "stop.fill")
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red.opacity(0.15))
                                        .cornerRadius(12)
                                }
                            } else {
                                Button {
                                    reRun()
                                } label: {
                                    Label("إعادة التشغيل", systemImage: "arrow.clockwise")
                                        .foregroundColor(AppColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(AppColors.accent.opacity(0.15))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(run.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLogs) {
                if let job = selectedJob {
                    JobLogsSheet(job: job)
                }
            }
        }
        .onAppear {
            Task { await loadJobs() }
        }
    }

    private var runInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: run.statusIcon)
                    .font(.title2)
                    .foregroundColor(run.statusColor)
                Text(run.displayConclusion)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
            }

            HStack {
                Label(run.head_branch, systemImage: "branch")
                Spacer()
                Label(run.event ?? "", systemImage: "bolt.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(12)
    }

    private func jobRow(_ job: WorkflowJob) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .foregroundColor(AppColors.accent)
            Text(job.name)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(12)
    }

    private func loadJobs() async {
        guard let user = gitHubService.currentUser else { return }
        let owner = user.login
        let repoName = run.head_branch
        jobs = await gitHubService.fetchJobs(
            owner: owner,
            repo: extractRepoName(from: run.html_url),
            runId: run.id
        )
    }

    private func reRun() {
        guard let user = gitHubService.currentUser else { return }
        Task {
            await gitHubService.reRunWorkflow(
                owner: user.login,
                repo: extractRepoName(from: run.html_url),
                runId: run.id
            )
        }
    }

    private func cancelRun() {
        guard let user = gitHubService.currentUser else { return }
        Task {
            await gitHubService.cancelWorkflow(
                owner: user.login,
                repo: extractRepoName(from: run.html_url),
                runId: run.id
            )
        }
    }

    private func extractRepoName(from url: String) -> String {
        let parts = url.components(separatedBy: "/")
        if let index = parts.firstIndex(of: "repos"), parts.count > index + 2 {
            return parts[index + 2]
        }
        return ""
    }
}

// MARK: - Job Logs Sheet
struct JobLogsSheet: View {
    @EnvironmentObject var gitHubService: GitHubService
    let job: WorkflowJob
    @State private var logs: [BuildLog] = []
    @State private var filterType: BuildLog.LogLineType? = nil
    @State private var searchText = ""

    var filteredLogs: [BuildLog] {
        var result = logs

        if let filter = filterType {
            result = result.filter { log in
                switch filter {
                case .error: return log.type == .error
                case .warning: return log.type == .warning
                case .command: return log.type == .command
                case .normal: return log.type == .normal
                }
            }
        }

        if !searchText.isEmpty {
            result = result.filter { log in
                log.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var errorCount: Int { logs.filter { $0.type == .error }.count }
    var warningCount: Int { logs.filter { $0.type == .warning }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter bar
                    filterBar

                    // Logs
                    if filteredLogs.isEmpty {
                        VStack {
                            Spacer()
                            Text("لا توجد سجلات")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(filteredLogs) { log in
                                        logRow(log)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(job.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "بحث في السجلات...")
        }
        .onAppear {
            Task { await loadLogs() }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton("الكل", nil)
                filterButton("أخطاء \(errorCount)", .error)
                filterButton("تحذيرات \(warningCount)", .warning)
                filterButton("أوامر", .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(hex: "12121A"))
    }

    private func filterButton(_ title: String, _ type: BuildLog.LogLineType?) -> some View {
        Button {
            filterType = type
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(filterType == type ? AppColors.accent : Color(hex: "2A2A3A"))
                .foregroundColor(filterType == type ? .white : .secondary)
                .cornerRadius(8)
        }
    }

    private func logRow(_ log: BuildLog) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(log.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "555570"))
                .frame(width: 35, alignment: .trailing)

            Text(log.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(
                    log.type == .error
                    ? Color(hex: "FF6B6B")
                    : log.type == .warning
                    ? Color(hex: "FFD93D")
                    : Color(hex: "C0C0D0")
                )
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            log.type == .error
            ? Color(hex: "FF6B6B").opacity(0.08)
            : log.type == .warning
            ? Color(hex: "FFD93D").opacity(0.05)
            : Color.clear
        )
    }

    private func loadLogs() async {
        guard let user = gitHubService.currentUser else { return }
        let repoName = extractRepoName(from: job.name)
        logs = await gitHubService.fetchJobLogs(
            owner: user.login,
            repo: repoName.isEmpty ? "" : repoName,
            jobId: job.id
        )
        // Fallback: استخدم buildLogs إذا كانت متوفرة
        if logs.isEmpty && !gitHubService.buildLogs.isEmpty {
            logs = gitHubService.buildLogs
        }
    }

    private func extractRepoName(from url: String) -> String {
        // محاولة استخراج اسم الريبو
        return ""
    }
}
