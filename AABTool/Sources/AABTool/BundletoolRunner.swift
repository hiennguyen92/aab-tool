import Foundation

enum BundletoolMode: String, CaseIterable, Identifiable {
    case universal = "build-apks --mode=universal"
    case split = "build-apks" // Default split apks
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .universal: return "Universal APK"
        case .split: return "Split APKs (default)"
        }
    }
}

class BundletoolRunner: ObservableObject {
    @Published var isRunning = false
    @Published var outputLog = ""
    @Published var errorLog = ""
    
    func run(
        javaPath: String,
        javaURL: URL?,
        aabPath: String,
        keystorePath: String,
        keystorePassword: String,
        keyAlias: String,
        keyPassword: String,
        outputDir: String,
        mode: BundletoolMode
    ) async throws {
        
        guard let bundletoolURL = Bundle.module.url(forResource: "bundletool", withExtension: "jar") else {
             throw NSError(domain: "Bundletool", code: 404, userInfo: [NSLocalizedDescriptionKey: "bundletool.jar not found in bundle resources."])
        }

        let outputApksPath = URL(fileURLWithPath: outputDir).appendingPathComponent("output.apks").path
        
        var arguments = [
            "-jar", bundletoolURL.path,
            "build-apks",
            "--bundle=\(aabPath)",
            "--output=\(outputApksPath)",
            "--ks=\(keystorePath)",
            "--ks-pass=pass:\(keystorePassword)",
            "--ks-key-alias=\(keyAlias)",
            "--key-pass=pass:\(keyPassword)",
            "--overwrite"
        ]
        
        if mode == .universal {
            arguments.append("--mode=universal")
        }
        
        
        // Execute
        await execute(javaExecutable: javaPath, javaURL: javaURL, arguments: arguments)
    }

    func getCommandString(
        javaPath: String,
        aabPath: String,
        keystorePath: String,
        keystorePassword: String,
        keyAlias: String,
        keyPassword: String,
        outputDir: String,
        mode: BundletoolMode
    ) -> String {
        guard let bundletoolURL = Bundle.module.url(forResource: "bundletool", withExtension: "jar") else {
             return "Error: bundletool.jar not found"
        }

        let outputApksPath = URL(fileURLWithPath: outputDir).appendingPathComponent("output.apks").path
        
        var arguments = [
            javaPath,
            "-jar", bundletoolURL.path,
            "build-apks",
            "--bundle=\(aabPath)",
            "--output=\(outputApksPath)",
            "--ks=\(keystorePath)",
            "--ks-pass=pass:\(keystorePassword.isEmpty ? "*****" : keystorePassword)", 
            "--ks-key-alias=\(keyAlias)",
            "--key-pass=pass:\(keyPassword.isEmpty ? "*****" : keyPassword)",
            "--overwrite"
        ]
        
        if mode == .universal {
            arguments.append("--mode=universal")
        }
        
        
        return arguments.joined(separator: " ")
    }
    
    private func execute(javaExecutable: String, javaURL: URL?, arguments: [String]) async {
        await MainActor.run {
            self.isRunning = true
            self.outputLog = "Starting bundletool...\n"
            self.errorLog = ""
        }
        
        // Validation
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: javaExecutable) {
            await MainActor.run {
                self.outputLog += "Error: Java executable not found at path: \(javaExecutable)\n"
                self.isRunning = false
            }
            return
        }
        
        if !fileManager.isExecutableFile(atPath: javaExecutable) {
             await MainActor.run {
                self.outputLog += "Warning: File at \(javaExecutable) may not be executable.\n"
                self.outputLog += "Attempting to fix permissions...\n"
            }
            // Try to force executable permission (best effort)
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: javaExecutable)
        }
        
        // Double check executable status
        if !fileManager.isExecutableFile(atPath: javaExecutable) {
             await MainActor.run {
                self.outputLog += "CRITICAL: The Java file is NOT executable by this app.\n"
                self.outputLog += "ISSUE: App Sandbox is likely preventing execution.\n"
                self.outputLog += "SOLUTION: Ensure you have added the 'File Access: User Selected Files (Read/Write)' capability in Xcode Signing & Capabilities.\n"
                self.outputLog += "NOTE: Executing external binaries in Sandbox is restricted. If this fails, consider bundling a valid JRE inside the app or verifying you selected the executable explicitly.\n"
            }
        }
        
        let task = Process()
        if let url = javaURL {
            task.executableURL = url
        } else {
            task.executableURL = URL(fileURLWithPath: javaExecutable)
        }
        
        // Pass arguments
        task.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            await MainActor.run {
                self.outputLog += output
                if !error.isEmpty {
                    self.outputLog += "\nERRORS/WARNINGS:\n" + error
                    self.errorLog = error
                }
                self.outputLog += "\nFinished."
                self.isRunning = false
            }
        } catch {
            await MainActor.run {
                self.errorLog = error.localizedDescription
                self.outputLog += "\nExecution Failed: \(error.localizedDescription)"
                self.isRunning = false
            }
        }
    }
    func unzipApks(at apksURL: URL, to destinationURL: URL) async {
        await MainActor.run {
            self.outputLog += "\n\nExtracting APKS..."
        }
        
        let fileManager = FileManager.default
        
        // Create destination if needed
        do {
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            await MainActor.run {
                self.outputLog += "\nError creating unzip directory: \(error.localizedDescription)"
            }
            return
        }
        
        // Unzip executable resolution
        var unzipExecutable = "/usr/bin/unzip"
        
        let arguments = ["-o", apksURL.path, "-d", destinationURL.path]
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: unzipExecutable)
        task.arguments = arguments
        
        // Fix permissions if embedded
        if unzipExecutable != "/usr/bin/unzip" {
             let fm = FileManager.default
             if !fm.isExecutableFile(atPath: unzipExecutable) {
                 try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: unzipExecutable)
             }
        }
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe // Capture all into one log
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            await MainActor.run {
                if task.terminationStatus == 0 {
                    self.outputLog += "\n\n✅ Extraction Complete"
                    self.outputLog += "\n📁 Output: \(destinationURL.path)\n"
                    
                    // Recursively find all APKs
                    var allApks: [(relativePath: String, size: String)] = []
                    
                    if let enumerator = fileManager.enumerator(at: destinationURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            if fileURL.pathExtension.lowercased() == "apk" {
                                let relativePath = fileURL.path.replacingOccurrences(of: destinationURL.path + "/", with: "")
                                let fileSize: String
                                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                                   let bytes = attrs[.size] as? Int64 {
                                    let mb = Double(bytes) / 1_048_576.0
                                    fileSize = String(format: "%.2f MB", mb)
                                } else {
                                    fileSize = "? MB"
                                }
                                allApks.append((relativePath: relativePath, size: fileSize))
                            }
                        }
                    }
                    
                    if allApks.isEmpty {
                        self.outputLog += "\n⚠️ No .apk files found in extracted contents."
                    } else {
                        self.outputLog += "\n📦 APK Files (\(allApks.count)):\n"
                        self.outputLog += String(repeating: "─", count: 50) + "\n"
                        for apk in allApks {
                            self.outputLog += "  📄 \(apk.relativePath)  [\(apk.size)]\n"
                        }
                        self.outputLog += String(repeating: "─", count: 50)
                    }
                } else {
                    self.outputLog += "\n\n❌ Unzip Failed:\n" + output
                }
            }
        } catch {
             await MainActor.run {
                self.outputLog += "\nFailed to run unzip: \(error.localizedDescription)"
            }
        }
    }
}
