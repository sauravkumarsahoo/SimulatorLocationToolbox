//
//  LocationPlaybackManager.swift
//  SimulatorLocationToolbox
//
//  Manages GPX playback to iOS Simulator
//

import Foundation
import CoreLocation
import Combine

enum LocationMode: String, CaseIterable {
    case gpxFile = "GPX File"
    case customLocation = "Custom Location"
}

struct SimulatorDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let state: String
    let runtime: String
    
    var displayName: String {
        "\(name) (\(state))"
    }
    
    var isBooted: Bool {
        state == "Booted"
    }
}

@MainActor
class LocationPlaybackManager: ObservableObject {
    @Published var trackPoints: [GPXTrackPoint] = []
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentIndex = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var statusMessage = "Ready"
    @Published var totalPoints = 0
    @Published var fileName: String?
    @Published var locationMode: LocationMode = .gpxFile
    @Published var customLatitude: String = ""
    @Published var customLongitude: String = ""
    @Published var availableDevices: [SimulatorDevice] = []
    @Published var selectedDevice: SimulatorDevice?
    @Published var isRefreshingDevices = false
    
    private var playbackTask: Task<Void, Never>?
    private let process = Process()
    
    var progress: Double {
        guard totalPoints > 0 else { return 0 }
        return Double(currentIndex) / Double(totalPoints)
    }
    
    var formattedProgress: String {
        "\(currentIndex) / \(totalPoints)"
    }
    
    func loadGPXFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let parser = GPXParser()
            
            if let points = parser.parse(data: data) {
                trackPoints = points
                totalPoints = points.count
                currentIndex = 0
                fileName = url.lastPathComponent
                statusMessage = "Loaded \(points.count) points from \(url.lastPathComponent)"
            } else {
                statusMessage = "Error: Failed to parse GPX file"
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    func startPlayback() {
        guard !trackPoints.isEmpty || locationMode == .customLocation else {
            statusMessage = "Error: No track points loaded"
            return
        }
        
        isPlaying = true
        isPaused = false
        
        if locationMode == .customLocation {
            playCustomLocation()
        } else {
            playGPXTrack()
        }
    }
    
    private func playCustomLocation() {
        guard let lat = Double(customLatitude), let lon = Double(customLongitude) else {
            statusMessage = "Error: Invalid coordinates"
            isPlaying = false
            return
        }
        
        statusMessage = "Setting custom location..."
        setSimulatorLocation(latitude: lat, longitude: lon)
        statusMessage = "Custom location set: \(lat), \(lon)"
        isPlaying = false
    }
    
    private func playGPXTrack() {
        playbackTask?.cancel()
        
        playbackTask = Task { [weak self] in
            guard let self = self else { return }
            
            if self.currentIndex >= self.trackPoints.count {
                self.currentIndex = 0
            }
            
            while self.currentIndex < self.trackPoints.count && self.isPlaying {
                if Task.isCancelled { break }
                
                let point = self.trackPoints[self.currentIndex]
                
                await MainActor.run {
                    self.statusMessage = "Playing point \(self.currentIndex + 1) of \(self.totalPoints)"
                }
                
                self.setSimulatorLocation(
                    latitude: point.coordinate.latitude,
                    longitude: point.coordinate.longitude
                )
                
                // Calculate delay based on timestamps or use fixed delay
                var delaySeconds = 1.0 / self.playbackSpeed
                
                if self.currentIndex < self.trackPoints.count - 1,
                   let currentTime = point.timestamp,
                   let nextTime = self.trackPoints[self.currentIndex + 1].timestamp {
                    let timeDiff = nextTime.timeIntervalSince(currentTime)
                    delaySeconds = max(0.1, timeDiff / self.playbackSpeed)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                
                await MainActor.run {
                    self.currentIndex += 1
                }
            }
            
            await MainActor.run {
                if self.currentIndex >= self.trackPoints.count {
                    self.statusMessage = "Playback completed"
                    self.currentIndex = 0
                }
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }
    
    func pausePlayback() {
        isPaused = true
        isPlaying = false
        playbackTask?.cancel()
        statusMessage = "Paused at point \(currentIndex + 1)"
    }
    
    func resumePlayback() {
        isPaused = false
        startPlayback()
    }
    
    func stopPlayback() {
        isPlaying = false
        isPaused = false
        playbackTask?.cancel()
        currentIndex = 0
        statusMessage = "Stopped"
    }
    
    func searchLocation(query: String) async {
        statusMessage = "Searching for '\(query)'..."
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            
            if let location = placemarks.first?.location {
                await MainActor.run {
                    self.customLatitude = String(format: "%.6f", location.coordinate.latitude)
                    self.customLongitude = String(format: "%.6f", location.coordinate.longitude)
                    self.statusMessage = "Found: \(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
            } else {
                await MainActor.run {
                    self.statusMessage = "No results found for '\(query)'"
                }
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Search error: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshDevices() async {
        isRefreshingDevices = true
        statusMessage = "Refreshing device list..."
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["simctl", "list", "devices", "available", "--json"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let devices = parseDevicesList(from: data)
            
            await MainActor.run {
                self.availableDevices = devices
                
                // Auto-select the first booted device, or the first device if none are booted
                if self.selectedDevice == nil {
                    self.selectedDevice = devices.first(where: { $0.isBooted }) ?? devices.first
                }
                
                self.isRefreshingDevices = false
                self.statusMessage = "Found \(devices.count) device(s)"
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Error refreshing devices: \(error.localizedDescription)"
                self.isRefreshingDevices = false
            }
        }
    }
    
    private func parseDevicesList(from data: Data) -> [SimulatorDevice] {
        var devices: [SimulatorDevice] = []
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
            return devices
        }
        
        for (runtime, deviceList) in devicesDict {
            for device in deviceList {
                guard let udid = device["udid"] as? String,
                      let name = device["name"] as? String,
                      let state = device["state"] as? String,
                      let isAvailable = device["isAvailable"] as? Bool,
                      isAvailable else {
                    continue
                }
                
                let simulatorDevice = SimulatorDevice(
                    id: udid,
                    name: name,
                    state: state,
                    runtime: runtime
                )
                devices.append(simulatorDevice)
            }
        }
        
        // Sort: Booted devices first, then by name
        return devices.sorted { lhs, rhs in
            if lhs.isBooted != rhs.isBooted {
                return lhs.isBooted
            }
            return lhs.name < rhs.name
        }
    }
    
    private func setSimulatorLocation(latitude: Double, longitude: Double) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        
        // Use selected device ID or fallback to "booted"
        let deviceTarget = selectedDevice?.id ?? "booted"
        
        task.arguments = [
            "simctl",
            "location",
            deviceTarget,
            "set",
            String(format: "%.6f,%.6f", latitude, longitude)
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
