import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showAABPicker = false
    @State private var showKeystorePicker = false
    @State private var showOutputDirPicker = false
    @State private var showJavaPicker = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel: Form
            VStack(alignment: .leading, spacing: 20) {
                Text("Configuration")
                    .font(.headline)
                
                Group {
                    // AAB File
                    VStack(alignment: .leading) {
                        Text("AAB File")
                        HStack {
                            TextField("Select .aab file", text: $viewModel.aabPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                            Button("Browse") {
                                showAABPicker = true
                            }
                            .fileImporter(isPresented: $showAABPicker, allowedContentTypes: [.item], onCompletion: { result in
                                handleFileSelection(result: result) { url in
                                   if url.pathExtension.lowercased() == "aab" {
                                       viewModel.setAABURL(url)
                                   } else if url.pathExtension.isEmpty {
                                        viewModel.setAABURL(url)
                                   }
                                }
                            })
                        }
                    }
                    
                    Divider()
                    
                    // Keystore
                    VStack(alignment: .leading) {
                        Text("Keystore")
                        // History Dropdown
                        if !viewModel.keystoreHistory.isEmpty {
                            Menu("Recent Keystores") {
                                ForEach(viewModel.keystoreHistory) { profile in
                                    Button(action: {
                                        viewModel.selectKeystoreFromHistory(profile)
                                    }) {
                                        Text("\(profile.keyAlias) - \(URL(fileURLWithPath: profile.keystorePath).lastPathComponent)")
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    viewModel.clearHistory()
                                }) {
                                    Label("Clear History", systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 5)
                        }
                        
                        HStack {
                            TextField("Select .keystore/.jks file", text: $viewModel.keystorePath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                            Button("Browse") {
                                showKeystorePicker = true
                            }
                            .fileImporter(isPresented: $showKeystorePicker, allowedContentTypes: [.item], onCompletion: { result in
                                 handleFileSelection(result: result) { url in
                                     let ext = url.pathExtension.lowercased()
                                     if ["jks", "keystore"].contains(ext) {
                                         viewModel.setKeystoreURL(url)
                                     }
                                 }
                            })
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Keystore Password")
                            SecureField("Password", text: $viewModel.keystorePassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Key Alias")
                            TextField("Alias", text: $viewModel.keyAlias)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Key Password")
                            SecureField("Password", text: $viewModel.keyPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    
                    Divider()

                    // Output Directory
                    VStack(alignment: .leading) {
                        Text("Output Directory")
                        HStack {
                            TextField("Select output folder", text: $viewModel.outputDirPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                            Button("Browse") {
                                showOutputDirPicker = true
                            }
                            .fileImporter(isPresented: $showOutputDirPicker, allowedContentTypes: [.folder], onCompletion: { result in
                                handleFileSelection(result: result) { url in
                                    viewModel.setOutputURL(url)
                                }
                            })
                        }
                    }

                    Divider()

                    // Java Configuration
                    VStack(alignment: .leading) {
                        Text("Java Path (Optional)")
                        HStack {
                            TextField("/usr/bin/java", text: $viewModel.javaPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: viewModel.javaPath) { newValue in
                                    viewModel.setJavaPath(newValue)
                                }
                            Button("Browse") {
                                showJavaPicker = true
                            }
                            .fileImporter(isPresented: $showJavaPicker, allowedContentTypes: [.executable, .item], onCompletion: { result in
                                handleFileSelection(result: result) { url in
                                    viewModel.setJavaURL(url)
                                }
                            })
                        }
                        Text("If default java fails, select your java executable (e.g. inside JDK Home/bin/java)").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
            }
            .padding()
            .frame(width: 400)
            
            Divider()
            
            Divider()
            
            // Right Panel: Output and Preview
            VStack(spacing: 0) {
                // Top Half: Command Preview
                VStack(alignment: .leading) {
                    Text("Command Preview")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ScrollView {
                        Text(viewModel.commandPreview)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
                    
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(viewModel.commandPreview, forType: .string)
                    }) {
                        Label("Copy Command", systemImage: "doc.on.doc")
                    }
                    .padding(.top, 5)
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 10)
                
                Divider()
                
                // Bottom Half: Output Log
                VStack(alignment: .leading) {
                    Text("Output Log")
                        .font(.headline)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                    
                    ScrollView {
                        Text(viewModel.outputLog)
                            .font(.system(.body, design: .monospaced))
                            .padding(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(5)
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Mode + Convert
                VStack(spacing: 8) {
                    HStack {
                        Text("Mode")
                            .font(.subheadline)
                        Picker("", selection: $viewModel.selectedMode) {
                            ForEach(BundletoolMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Button(action: {
                        viewModel.convert()
                    }) {
                        Text(viewModel.isConverting ? "Converting..." : "Convert AAB to APK")
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isConverting || viewModel.aabPath.isEmpty || viewModel.keystorePath.isEmpty || viewModel.outputDirPath.isEmpty)
                }
                .padding(.top, 10)
            }
            .padding()
        }
        // File Pickers

    }
    
    private func handleFileSelection(result: Result<URL, Error>, action: (URL) -> Void) {
        switch result {
        case .success(let url):
            // We pass the URL to the ViewModel which will handle security scope retention
            action(url)
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
}
