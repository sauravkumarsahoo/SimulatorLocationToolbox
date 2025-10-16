//
//  ContentView.swift
//  SimulatorLocationToolbox
//
//  Main view for Simulator Location Toolbox
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var manager = LocationPlaybackManager()
    @State private var showFilePicker = false
    @State private var searchQuery = ""
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            HStack(spacing: 0) {
                // Left Panel - Controls
                VStack(alignment: .leading, spacing: 16) {
                    controlsSection
                }
                .frame(width: 350)
                .padding()
                
                Divider()
                
                // Right Panel - Map
                mapSection
            }
            
            Divider()
            
            // Status Bar
            statusBar
        }
        .frame(minWidth: 900, minHeight: 600)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .task {
            // Refresh devices when view appears
            await manager.refreshDevices()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "location.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Simulator Location Toolbox")
                    .font(.headline)
                Text("Control iOS Simulator Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Link(destination: URL(string: "https://gpx.studio/app")!) {
                Label("Create GPX File", systemImage: "arrow.up.forward.app")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Device Selection
                deviceSelectionSection
                
                Divider()
                
                // Location Mode Selection
                locationModeSection
                
                Divider()
                
                // Show appropriate sections based on mode
                if manager.locationMode == .gpxFile {
                    // File Selection
                    fileSelectionSection
                    
                    Divider()
                    
                    // Playback Controls
                    playbackControlsSection
                    
                    Divider()
                    
                    // Playback Settings
                    playbackSettingsSection
                } else {
                    // Custom Location
                    customLocationSection
                }
            }
        }
    }
    
    private var deviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target Device")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await manager.refreshDevices()
                    }
                }) {
                    if manager.isRefreshingDevices {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(manager.isRefreshingDevices)
                .help("Refresh device list")
            }
            
            if manager.availableDevices.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("No devices found. Click refresh.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Picker("Device", selection: $manager.selectedDevice) {
                        ForEach(manager.availableDevices) { device in
                            HStack {
                                Text(device.name)
                                if device.isBooted {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 6))
                                }
                            }
                            .tag(device as SimulatorDevice?)
                        }
                    }
                    .labelsHidden()

                    if let selected = manager.selectedDevice {
                        HStack {
                            Image(systemName: selected.isBooted ? "circle.fill" : "circle")
                                .foregroundColor(selected.isBooted ? .green : .gray)
                                .font(.system(size: 8))
                            Text(selected.state)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var locationModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Source")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(LocationMode.allCases, id: \.self) { mode in
                    Button(action: {
                        manager.locationMode = mode
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: manager.locationMode == mode ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 14))
                            Text(mode.rawValue)
                                .font(.system(size: 13))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(manager.locationMode == mode ? .primary : .secondary)
                }
                Spacer()
            }
        }
    }
    
    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPX File")
                .font(.headline)
            
            Button(action: { showFilePicker = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Select GPX File")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            if let fileName = manager.fileName {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(fileName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var customLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Coordinates")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latitude")
                        .font(.caption)
                    TextField("e.g., 17.413399", text: $manager.customLatitude)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Longitude")
                        .font(.caption)
                    TextField("e.g., 78.460046", text: $manager.customLongitude)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Button(action: { manager.startPlayback() }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Set Location")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.customLatitude.isEmpty || manager.customLongitude.isEmpty)
        }
    }
    
    private var playbackControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback Controls")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: { manager.startPlayback() }) {
                    Image(systemName: manager.isPaused ? "play.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .disabled(manager.trackPoints.isEmpty || (manager.isPlaying && !manager.isPaused))
                
                Button(action: { manager.pausePlayback() }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2)
                }
                .disabled(!manager.isPlaying)
                
                Button(action: { manager.stopPlayback() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                }
                .disabled(!manager.isPlaying && !manager.isPaused)
                
                Spacer()
                
                if manager.isPlaying {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Progress
            if manager.totalPoints > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: manager.progress)
                    Text(manager.formattedProgress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(manager.playbackSpeed, specifier: "%.1f")x")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    ForEach([0.5, 1.0, 2.0, 5.0], id: \.self) { speed in
                        Button("\(speed, specifier: "%.1f")x") {
                            manager.playbackSpeed = speed
                        }
                        .buttonStyle(.bordered)
                        .tint(manager.playbackSpeed == speed ? .blue : .gray)
                    }
                }
                
                Slider(value: $manager.playbackSpeed, in: 0.1...10.0, step: 0.1)
                    .disabled(manager.isPlaying)
            }
        }
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        VStack(spacing: 0) {
            if manager.locationMode == .customLocation {
                // Interactive map for custom location
                CustomLocationMapView(
                    selectedLatitude: $manager.customLatitude,
                    selectedLongitude: $manager.customLongitude,
                    searchQuery: $searchQuery,
                    isSearching: $isSearching
                )
            } else if manager.trackPoints.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No GPX file loaded")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select a GPX file to see the track on the map")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MapView(trackPoints: manager.trackPoints, currentIndex: manager.currentIndex)
            }
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            Image(systemName: manager.isPlaying ? "circle.fill" : "circle")
                .foregroundColor(manager.isPlaying ? .green : .gray)
                .imageScale(.small)
            
            Text(manager.statusMessage)
                .font(.caption)
            
            Spacer()
            
            if let fileName = manager.fileName {
                Text("File: \(fileName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helper Methods
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                manager.loadGPXFile(url: url)
            }
        case .failure(let error):
            manager.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        Task {
            await manager.searchLocation(query: searchQuery)
            isSearching = false
        }
    }
}

#Preview {
    ContentView()
}
