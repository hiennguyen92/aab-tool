import Foundation

struct KeystoreProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var keystorePath: String
    var outputDir: String
    var keyAlias: String
    var keystorePassword: String?
    var keyPassword: String?
    // Security Scoped Bookmark
    var bookmarkData: Data?
    var lastUsed: Date
}

class HistoryManager: ObservableObject {
    @Published var profiles: [KeystoreProfile] = []
    
    private let key = "KeystoreHistory"
    
    init() {
        loadHistory()
    }
    
    func saveProfile(keystoreURL: URL, outputDir: String, keyAlias: String, keystorePassword: String, keyPassword: String) {
        // Create bookmark
        var bookmark: Data? = nil
        do {
            bookmark = try keystoreURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Failed to create bookmark: \(error)")
        }
        
        // Check if exists and update, or append
        let newProfile = KeystoreProfile(
            keystorePath: keystoreURL.path,
            outputDir: outputDir,
            keyAlias: keyAlias,
            keystorePassword: keystorePassword,
            keyPassword: keyPassword,
            bookmarkData: bookmark,
            lastUsed: Date()
        )
        
        if let index = profiles.firstIndex(where: { $0.keystorePath == keystoreURL.path && $0.keyAlias == keyAlias }) {
            profiles[index] = newProfile
        } else {
            profiles.append(newProfile)
        }
        
        // Sort by date desc
        profiles.sort { $0.lastUsed > $1.lastUsed }
        
        persist()
    }
    
    func clearHistory() {
        profiles = []
        persist()
    }
    
    func deleteProfile(_ profile: KeystoreProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles.remove(at: index)
            persist()
        }
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([KeystoreProfile].self, from: data) {
            profiles = decoded
        }
    }
}
