//
//  CustomLocationMapView.swift
//  SimulatorLocationToolbox
//
//  Interactive map for selecting custom locations
//

import SwiftUI
import MapKit

struct CustomLocationMapView: View {
    @Binding var selectedLatitude: String
    @Binding var selectedLongitude: String
    @Binding var searchQuery: String
    @Binding var isSearching: Bool
    
    @State private var selectedLocation: Location?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var lastManualCoordinates: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                TextField("Search for a location...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: performSearch) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(searchQuery.isEmpty || isSearching)
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Interactive Map
            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition, interactionModes: [.all]) {
                        if let selectedLocation {
                            Marker(selectedLocation.address, coordinate: selectedLocation.coordinates)
                                .tint(.red)
                        }
                    }
                    .mapStyle(.standard)
                    .overlay(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { tapLocation in
                                if let mapCoordinate = proxy.convert(tapLocation, from: .local) {
                                    selectedLocation = Location(address: "Loading...", coordinates: mapCoordinate)
                                    selectedLatitude = String(format: "%.6f", mapCoordinate.latitude)
                                    selectedLongitude = String(format: "%.6f", mapCoordinate.longitude)
                                    lastManualCoordinates = "\(selectedLatitude),\(selectedLongitude)"
                                    reverseGeocode(location: mapCoordinate)
                                }
                            }
                            .allowsHitTesting(true)
                    )
                }
            }
            .onChange(of: selectedLatitude + "," + selectedLongitude) { oldValue, newValue in
                // Update map when coordinates are manually entered
                if newValue != lastManualCoordinates {
                    updateFromManualCoordinates()
                }
            }
            
            Divider()
            
            // Selected Location Summary
            if let selectedLocation {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedLocation.address)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text("\(String(format: "%.6f", selectedLocation.coordinates.latitude)), \(String(format: "%.6f", selectedLocation.coordinates.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
            } else {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.secondary)
                    Text("Tap on the map or search to select a location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        geocode(address: searchQuery)
    }
    
    private func geocode(address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            isSearching = false
            geocodeHandler(placemarks: placemarks, error: error)
        }
    }
    
    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(
            CLLocation(latitude: location.latitude, longitude: location.longitude)
        ) { placemarks, error in
            geocodeHandler(placemarks: placemarks, error: error)
        }
    }
    
    private func geocodeHandler(placemarks: [CLPlacemark]?, error: Error?) {
        if error != nil {
            print("Failed to retrieve location")
            return
        }
        
        guard let placemarks = placemarks, let location = placemarks.first else {
            print("No Matching Location Found")
            return
        }
        
        let newLocation = Location(
            address: inlineAddress(from: location),
            coordinates: location.location!.coordinate
        )
        
        selectedLocation = newLocation
        selectedLatitude = String(format: "%.6f", newLocation.coordinates.latitude)
        selectedLongitude = String(format: "%.6f", newLocation.coordinates.longitude)
        
        // Update camera to show selected location
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: newLocation.coordinates,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }
    }
    
    private func inlineAddress(from placemark: CLPlacemark) -> String {
        let name = placemark.name ?? ""
        let street = placemark.thoroughfare ?? ""
        let city = placemark.locality ?? ""
        let state = placemark.administrativeArea ?? ""
        let postalCode = placemark.postalCode ?? ""
        let country = placemark.country ?? ""

        return "\(name)\(name != "" && street != "" ? ", " : "")\(street)\(street != "" && postalCode != "" ? ", " : "")\(postalCode)\(postalCode != "" && city != "" ? ", " : "") \(city)\(city != "" && state != "" ? ", " : "")\(state)\(state != "" && country != "" ? ", " : "")\(country)"
    }
    
    private func updateFromManualCoordinates() {
        guard let lat = Double(selectedLatitude),
              let lon = Double(selectedLongitude),
              lat >= -90, lat <= 90,
              lon >= -180, lon <= 180 else {
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        lastManualCoordinates = "\(selectedLatitude),\(selectedLongitude)"
        
        // Update camera position
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }
        
        // Reverse geocode to get address
        reverseGeocode(location: coordinate)
    }
}

struct Location {
    let address: String
    let coordinates: CLLocationCoordinate2D
}
