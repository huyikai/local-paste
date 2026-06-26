import Foundation

/// Result of a version check against the GitHub Releases API.
enum UpdateCheckResult: Equatable {
    case checking
    case upToDate
    case newVersion(version: String, downloadURL: URL)
    case error(message: String)
}

/// Checks for new versions using the GitHub Releases API.
final class UpdateChecker {

    private let repoOwner: String
    private let repoName: String
    private let currentVersion: String

    private let defaults = UserDefaults.standard

    init(repoOwner: String = "huyikai", repoName: String = "local-paste") {
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Public API

    /// Perform an async check against the GitHub API.
    /// Must be called on the main actor for UI updates.
    @MainActor
    func check() async -> UpdateCheckResult {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            return .error(message: "Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .error(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .error(message: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let msg = "GitHub API returned \(httpResponse.statusCode)"
            return .error(message: msg)
        }

        struct Release: Decodable {
            let tagName: String
            let htmlURL: URL

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        let release: Release
        do {
            release = try JSONDecoder().decode(Release.self, from: data)
        } catch {
            return .error(message: "Failed to parse release data")
        }

        let latestTag = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

        guard isNewer(latestTag, than: currentVersion) else {
            saveNotified(version: nil)
            return .upToDate
        }

        // Only show notification if we haven't already notified for this version
        if lastNotifiedVersion == latestTag {
            return .upToDate
        }

        saveNotified(version: latestTag)
        return .newVersion(version: release.tagName, downloadURL: release.htmlURL)
    }

    // MARK: - Rate limiting / persistence

    /// The last version the user was notified about.
    var lastNotifiedVersion: String? {
        defaults.string(forKey: "lastNotifiedVersion")
    }

    /// When the last check was performed.
    var lastCheckDate: Date? {
        get { defaults.object(forKey: "lastUpdateCheck") as? Date }
        set { defaults.set(newValue, forKey: "lastUpdateCheck") }
    }

    /// Whether a check is due (more than 24 hours since last check, or never checked).
    var isCheckDue: Bool {
        guard let last = lastCheckDate else { return true }
        return Date().timeIntervalSince(last) >= 86400
    }

    private func saveNotified(version: String?) {
        defaults.set(version, forKey: "lastNotifiedVersion")
    }

    // MARK: - Version comparison

    /// Compare two semantic version strings, returns true if `new` > `current`.
    private func isNewer(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let curParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, curParts.count) {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < curParts.count ? curParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }
}
