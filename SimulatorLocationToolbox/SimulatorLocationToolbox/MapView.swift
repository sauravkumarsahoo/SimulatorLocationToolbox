//
//  MapView.swift
//  SimulatorLocationToolbox
//
//  Display GPX track on a map
//

import SwiftUI
import MapKit

struct MapView: View {
    let trackPoints: [GPXTrackPoint]
    let currentIndex: Int
    
    @State private var position: MapCameraPosition
    
    init(trackPoints: [GPXTrackPoint], currentIndex: Int) {
        self.trackPoints = trackPoints
        self.currentIndex = currentIndex
        
        // Calculate initial camera position
        if let first = trackPoints.first {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        } else {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }
    
    var body: some View {
        Map(position: $position) {
            ForEach(annotationItems) { item in
                Annotation("", coordinate: item.coordinate) {
                    if item.isCurrent {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 12, height: 12)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            if newValue < trackPoints.count {
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: trackPoints[newValue].coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    private var annotationItems: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        // Add start point
        if let first = trackPoints.first {
            items.append(MapAnnotationItem(
                id: "start",
                coordinate: first.coordinate,
                color: .green,
                isCurrent: false
            ))
        }
        
        // Add current point
        if currentIndex < trackPoints.count {
            items.append(MapAnnotationItem(
                id: "current",
                coordinate: trackPoints[currentIndex].coordinate,
                color: .blue,
                isCurrent: true
            ))
        }
        
        // Add end point
        if let last = trackPoints.last, trackPoints.count > 1 {
            items.append(MapAnnotationItem(
                id: "end",
                coordinate: last.coordinate,
                color: .red,
                isCurrent: false
            ))
        }
        
        return items
    }
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let color: Color
    let isCurrent: Bool
}
