import SwiftUI

struct ActionsView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedRepo: GitHubRepo?
    @State private var showRepoSelector = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            VStack(spacing: 0) {
                headerView
                if let repo = selectedRepo {
                    runsListView(repo: repo)
                } else {
                    repoSelectorView
                }
            }
        }
        .sheet(isPresented: $showRepoSelector, content: { repoPickerSheet })
        .onAppear {
            if selectedRepo == nil, let first = gitHubService.repositories.first {
                selectedRepo = first
            }
        }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Actions")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                if let repo = selectedRepo {
                    Text(repo.name)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Button { showRepoSelector = true } label: {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.accent)
            }
            Button {
                if let repo = selectedRepo { Task { await gitHubService.fetchWorkflowRuns(owner: repo.ownerLogin, repo: repo.name) } }
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }
    
    func runsListView(repo: GitHubRepo) -> some View {
        Group {
            if gitHubService.isLoading { LoadingCard(); Spacer() } else if gitHubService.workflowRuns.isEmpty {
                EmptyStateView(icon: "bolt.circle", title: "No Runs", subtitle: "No workflow runs found").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(gitHubService.workflowRuns) { run in runCard(run, repo: repo) }
                    }.padding(.vertical)
                }
            }
        }
    }
    
    func runCard(_ run: WorkflowRun, repo: GitHubRepo) -> some View {
        NavigationLink(destination: LogDetailView(run: run, repo: repo)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusIcon(run.status, run.conclusion)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.text)
                        Text(run.headCommit.message.components(separatedBy: "\n").first ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                HStack {
                    Label(run.actor?.login ?? "GitHub", systemImage: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(run.createdAt.relativeFormatted())
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 8) {
                    Text(run.status.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusColor(run.status, run.conclusion))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(run.status, run.conclusion).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("#\(run.runNumber)")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    func statusIcon(_ status: String, _ conclusion: String?) -> some View {
        let (icon, color) = statusColorIcon(status, conclusion)
        return Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(color)
    }
    
    func statusColor(_ status: String, _ conclusion: String?) -> Color {
        switch conclusion {
        case "success": return Color(hex: "#6BCB77")
        case "failure", "cancelled", "timed_out": return Color(hex: "#FF6B6B")
        case "in_progress", "queued", "waiting", "pending": return AppColors.accent
        default: return AppColors.textSecondary
        }
    }
    
    func statusColorIcon(_ status: String, _ conclusion: String?) -> (String, Color) {
        switch conclusion {
        case "success": return ("checkmark.circle.fill", Color(hex: "#6BCB77"))
        case "failure": return ("xmark.circle.fill", Color(hex: "#FF6B6B"))
        case "cancelled", "timed_out": return ("minus.circle.fill", Color(hex: "#FFD93D"))
        case "in_progress", "queued", "waiting", "pending": return ("clock.fill", AppColors.accent)
        default: return ("questionmark.circle.fill", AppColors.textSecondary)
        }
    }
    
    var repoSelectorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)
            Text("Select a Repository")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.text)
            Text("Choose a repo to view workflow runs")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Button { showRepoSelector = true } label: {
                Text("Select Repository")
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
    
    var repoPickerSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    ForEach(gitHubService.repositories) { repo in
                        Button {
                            selectedRepo = repo
                            showRepoSelector = false
                            Task { await gitHubService.fetchWorkflowRuns(owner: repo.ownerLogin, repo: repo.name) }
                        } label: {
                            HStack {
                                Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                                    .foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                                Text(repo.name)
                                    .foregroundColor(AppColors.text)
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRepoSelector = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension GitHubRepo {
    var ownerLogin: String {
        fullName.components(separatedBy: "/").first ?? ""
    }
}

extension Date {
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

struct LogDetailView: View {
    let run: WorkflowRun
    let repo: GitHubRepo
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedJob: WorkflowJob?
    @State private var showLogViewer = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            VStack(spacing: 0) {
                runHeaderView
                if gitHubService.workflowJobs.isEmpty {
                    LoadingCard()
                    Spacer()
                } else {
                    jobsListView
                }
            }
        }
        .sheet(isPresented: $showLogViewer) {
            if let job = selectedJob {
                LogViewerSheet(job: job, repo: repo)
            }
        }
        .onAppear {
            Task { await gitHubService.fetchWorkflowJobs(owner: repo.ownerLogin, repo: repo.name, runId: run.id) }
        }
    }
    
    var runHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.text)
            Text(run.headCommit.message.components(separatedBy: "\n").first ?? "")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            HStack {
                Text(run.createdAt.relativeFormatted())
                Spacer()
                Text("#\(run.runNumber)")
            }
            .font(.system(size: 11))
            .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .background(AppColors.surface)
    }
    
    var jobsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(gitHubService.workflowJobs) { job in jobRow(job) }
            }.padding()
        }
    }
    
    func jobRow(_ job: WorkflowJob) -> some View {
        Button {
            selectedJob = job
            showLogViewer = true
        } label: {
            HStack {
                jobStatusIcon(job.conclusion)
                VStack(alignment: .leading) {
                    Text(job.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    if job.status == "completed" {
                        Text(job.completedAt?.relativeFormatted() ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(job.status.capitalized)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.accent)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    func jobStatusIcon(_ conclusion: String?) -> some View {
        let (icon, color) = statusIconFor(conclusion)
        return Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundColor(color)
    }
    
    func statusIconFor(_ conclusion: String?) -> (String, Color) {
        switch conclusion {
        case "success": return ("checkmark.circle.fill", Color(hex: "#6BCB77"))
        case "failure": return ("xmark.circle.fill", Color(hex: "#FF6B6B"))
        case "cancelled", "skipped": return ("minus.circle.fill", Color(hex: "#FFD93D"))
        default: return ("clock.fill", AppColors.accent)
        }
    }
}

struct LogViewerSheet: View {
    let job: WorkflowJob
    let repo: GitHubRepo
    @EnvironmentObject var gitHubService: GitHubService
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if isLoading { LoadingCard() }
                else if gitHubService.buildLogs.isEmpty {
                    EmptyStateView(icon: "doc.text", title: "No Logs", subtitle: "Logs unavailable")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(gitHubService.buildLogs) { line in logLine(line) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(job.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await gitHubService.fetchBuildLogs(owner: repo.ownerLogin, repo: repo.name, jobId: job.id)
                isLoading = false
            }
        }
    }
    
    func logLine(_ line: BuildLog) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(line.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 40, alignment: .trailing)
            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(colorFor(line.type))
        }
        .padding(.vertical, 2)
    }
    
    func colorFor(_ type: BuildLog.LogLineType) -> Color {
        switch type {
        case .error: return Color(hex: "#FF6B6B")
        case .warning: return Color(hex: "#FFD93D")
        case .success: return Color(hex: "#6BCB77")
        case .command: return AppColors.accent
        case .info: return Color(hex: "#C77DFF")
        case .normal: return AppColors.text
        }
    }
}