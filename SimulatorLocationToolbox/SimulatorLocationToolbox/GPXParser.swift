//
//  GPXParser.swift
//  SimulatorLocationToolbox
//
//  Parse GPX files and extract track points
//

import Foundation
import CoreLocation

struct GPXTrackPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double?
    let timestamp: Date?
}

class GPXParser: NSObject, XMLParserDelegate {
    private var trackPoints: [GPXTrackPoint] = []
    private var currentElement = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentElevation: Double?
    private var currentTime: Date?
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    func parse(data: Data) -> [GPXTrackPoint]? {
        trackPoints = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            return trackPoints
        }
        return nil
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "trkpt" {
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "ele":
            currentElevation = Double(trimmed)
        case "time":
            currentTime = dateFormatter.date(from: trimmed)
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trkpt" {
            if let lat = currentLat, let lon = currentLon {
                let trackPoint = GPXTrackPoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    elevation: currentElevation,
                    timestamp: currentTime
                )
                trackPoints.append(trackPoint)
            }
            // Reset current values
            currentLat = nil
            currentLon = nil
            currentElevation = nil
            currentTime = nil
        }
        currentElement = ""
    }
}
