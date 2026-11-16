import Foundation

/// Connection details for the Supabase project behind the app.
///
/// The publishable key is meant to ship inside client apps: on its own it
/// grants nothing, and every table is protected by row-level security.
enum BackendConfig {
    static let projectURL = "https://YOUR-PROJECT-REF.supabase.co"
    static let publishableKey = "YOUR-PUBLISHABLE-KEY"

    static var isConfigured: Bool {
        !projectURL.contains("YOUR-PROJECT-REF") && !publishableKey.contains("YOUR-PUBLISHABLE-KEY")
    }

    static var baseURL: URL {
        URL(string: projectURL) ?? URL(string: "https://invalid.invalid")!
    }
}
