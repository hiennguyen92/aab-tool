import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    @Published var aabPath: String = ""
    @Published var keystorePath: String = ""
    @Published var outputDirPath: String = ""
    @Published var javaPath: String = "/usr/bin/java" // Default

    @Published var keystorePassword: String = ""
    @Published var keyAlias: String = ""
    @Published var keyPassword: String = ""
    @Published var selectedMode: BundletoolMode = .split
    @Published var isConverting: Bool = false
    @Published var outputLog: String = ""
    
    @Published var keystoreHistory: [KeystoreProfile] = []
    
    // Hold security-scoped URLs to maintain access permissions
    private var aabURL: URL? {
        didSet {
            oldValue?.stopAccessingSecurityScopedResource()
            if let url = aabURL {
                _ = url.startAccessingSecurityScopedResource()
                aabPath = url.path
            } else {
                aabPath = ""
            }
        }
    }
    
    private var keystoreURL: URL? {
        didSet {
            oldValue?.stopAccessingSecurityScopedResource()
            if let url = keystoreURL {
                _ = url.startAccessingSecurityScopedResource()
                keystorePath = url.path
            } else {
                keystorePath = ""
            }
        }
    }
    
    private var outputDirURL: URL? {
        didSet {
            oldValue?.stopAccessingSecurityScopedResource()
            if let url = outputDirURL {
                _ = url.startAccessingSecurityScopedResource()
                outputDirPath = url.path
            } else {
                outputDirPath = ""
            }
        }
    }
    
    private var javaURL: URL? {
        didSet {
            oldValue?.stopAccessingSecurityScopedResource()
            if let url = javaURL {
                _ = url.startAccessingSecurityScopedResource()
                javaPath = url.path
                // Persist the Bookmark data if possible for future runs? 
                // For now just persist string, user might need to re-select in future sessions if strict sandbox.
                // But specifically for current session:
            }
        }
    }
    

    
    var commandPreview: String {
        // Preview assumes output logic same as execution
        // Fallback to AAB dir / output if not specified (descriptive only)
        let outputDir = !outputDirPath.isEmpty ? outputDirPath : (!aabPath.isEmpty ? URL(fileURLWithPath: aabPath).deletingLastPathComponent().appendingPathComponent("output").path : "/path/to/output")
        
        return runner.getCommandString(
            javaPath: javaPath,
            aabPath: aabPath,
            keystorePath: keystorePath,
            keystorePassword: keystorePassword,
            keyAlias: keyAlias,
            keyPassword: keyPassword,
            outputDir: outputDir,
            mode: selectedMode
        )
    }
    
    private let historyManager = HistoryManager()
    private let runner = BundletoolRunner()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 1. Check for Embedded JRE (Highest Priority)
        // We look for 'jre/bin/java' inside the bundle resources
        // Swift PM .process() preserves folder structure if copied, or we search via subdirectory
        if let embeddedJavaURL = Bundle.module.url(forResource: "java", withExtension: nil, subdirectory: "jre/bin") {
             self.javaPath = embeddedJavaURL.path
             self.javaURL = embeddedJavaURL
        } 
        // 2. Fallback to persisted user selection
        else if let savedJava = UserDefaults.standard.string(forKey: "JavaPath") {
            self.javaPath = savedJava
            // Note: URL bookmark resolution would be better here for sandbox, 
            // but for now we rely on user re-selecting if permissions are lost.
        }
        
        
        // Bind history
        historyManager.$profiles
            .assign(to: \.keystoreHistory, on: self)
            .store(in: &cancellables)
            
        // Bind runner status
        runner.$isRunning
            .assign(to: \.isConverting, on: self)
            .store(in: &cancellables)
        
        runner.$outputLog
            .assign(to: \.outputLog, on: self)
            .store(in: &cancellables)
    }
    
    deinit {
        aabURL?.stopAccessingSecurityScopedResource()
        keystoreURL?.stopAccessingSecurityScopedResource()
        outputDirURL?.stopAccessingSecurityScopedResource()
        javaURL?.stopAccessingSecurityScopedResource()
    }
    
    func setAABURL(_ url: URL) {
        self.aabURL = url
        // Default output directory to AAB's parent folder
        if outputDirPath.isEmpty {
            let parentDir = url.deletingLastPathComponent()
            self.setOutputURL(parentDir)
        }
    }
    
    func setKeystoreURL(_ url: URL) {
        self.keystoreURL = url
    }
    
    func setOutputURL(_ url: URL) {
        self.outputDirURL = url
    }
    
    func setJavaURL(_ url: URL) {
        self.javaURL = url
        self.javaPath = url.path
        UserDefaults.standard.set(url.path, forKey: "JavaPath")
    }
    
    func setJavaPath(_ path: String) {
        self.javaPath = path
        UserDefaults.standard.set(path, forKey: "JavaPath")
    }
    
    
    func selectKeystoreFromHistory(_ profile: KeystoreProfile) {
        self.keystorePath = profile.keystorePath
        self.keyAlias = profile.keyAlias
        self.keystorePassword = profile.keystorePassword ?? ""
        self.keyPassword = profile.keyPassword ?? ""
        
        // Resolve Bookmark
        if let bookmarkData = profile.bookmarkData {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    print("Bookmark is stale, should recreate.")
                    // If we had a mechanism to save back immediately, we would.
                }
                
                // Set URL (triggering startAccessing)
                self.setKeystoreURL(url)
                
            } catch {
                print("Failed to resolve bookmark: \(error)")
                self.outputLog = "Warning: Could not restore permission for recent file. Please browse manually."
            }
        } else {
             self.outputLog = "Warning: Recent file has no saved permission. Please browse manually."
        }
    }
    
    func clearHistory() {
        historyManager.clearHistory()
    }
    
    func convert() {
        // Ensure URLs are valid if set
        guard !aabPath.isEmpty, !keystorePath.isEmpty, !outputDirPath.isEmpty else {
            self.outputLog = "Error: Please select AAB, Keystore files, and Output Directory."
            return
        }
        
        Task {
            do {
                try await runner.run(
                    javaPath: javaPath,
                    javaURL: javaURL,
                    aabPath: aabPath,
                    keystorePath: keystorePath,
                    keystorePassword: keystorePassword,
                    keyAlias: keyAlias,
                    keyPassword: keyPassword,
                    outputDir: outputDirPath,
                    mode: selectedMode
                )
                
                // Unzip APKS if successful (check output log or assume success if no throw, though runner handles its own log?)
                // Runner captures errors in OutputLog but doesn't throw if process fails (it catches task internal error).
                // However, run() itself awaits execute() which catches errors.
                // We should check if output.apks exists essentially.
                
                let fileManager = FileManager.default
                let outputApksURL = URL(fileURLWithPath: self.outputDirPath).appendingPathComponent("output.apks")
                
                if fileManager.fileExists(atPath: outputApksURL.path) {
                    let unzipDir = URL(fileURLWithPath: self.outputDirPath).appendingPathComponent("apks")
                    await runner.unzipApks(at: outputApksURL, to: unzipDir)
                }
                
                // Save successful keystore usage to history
                if let url = self.keystoreURL {
                    DispatchQueue.main.async {
                        self.historyManager.saveProfile(
                            keystoreURL: url,
                            outputDir: self.outputDirPath,
                            keyAlias: self.keyAlias,
                            keystorePassword: self.keystorePassword,
                            keyPassword: self.keyPassword
                        )
                    }
                }
                
            } catch {
                self.outputLog = "Error: \(error.localizedDescription)"
            }
        }
    }
}
