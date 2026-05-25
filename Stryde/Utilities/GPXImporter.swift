import Foundation
import CoreLocation

enum GPXImporter {
    struct ImportedRun {
        let name: String
        let date: Date
        let duration: TimeInterval
        let distance: Double
        let sourceID: UUID?
        let tags: [String]
        let snapshots: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)]
    }

    static func parse(url: URL) -> ImportedRun? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.points.isEmpty else { return nil }

        let pts = delegate.points
        var totalDistance = 0.0
        for i in 1..<pts.count {
            let a = CLLocation(latitude: pts[i - 1].lat, longitude: pts[i - 1].lon)
            let b = CLLocation(latitude: pts[i].lat, longitude: pts[i].lon)
            totalDistance += b.distance(from: a)
        }

        return ImportedRun(
            name: delegate.name,
            date: pts.first!.time,
            duration: delegate.storedDuration ?? max(pts.last!.time.timeIntervalSince(pts.first!.time), 0),
            distance: totalDistance,
            sourceID: delegate.sourceID,
            tags: delegate.tags,
            snapshots: pts.map { (latitude: $0.lat, longitude: $0.lon, altitude: $0.alt, timestamp: $0.time) }
        )
    }
}

// MARK: - SAX delegate

private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var name = ""
    var sourceID: UUID? = nil
    var storedDuration: Double? = nil
    var tags: [String] = []
    var points: [(lat: Double, lon: Double, alt: Double, time: Date)] = []

    private var insideMetadata = false
    private var insideTrack = false
    private var insideTrkpt = false
    private var text = ""
    private var trkptLat: Double?
    private var trkptLon: Double?
    private var trkptAlt: Double?
    private var trkptTime: Date?

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        text = ""
        switch elementName {
        case "metadata":
            insideMetadata = true
        case "link":
            if insideMetadata, !insideTrack, let href = attributeDict["href"] {
                if href.hasPrefix("stryde://id/") {
                    sourceID = UUID(uuidString: String(href.dropFirst("stryde://id/".count)))
                } else if href.hasPrefix("stryde://duration/") {
                    storedDuration = Double(String(href.dropFirst("stryde://duration/".count)))
                }
            }
        case "trk":
            insideTrack = true
        case "trkpt":
            insideTrkpt = true
            trkptLat = attributeDict["lat"].flatMap(Double.init)
            trkptLon = attributeDict["lon"].flatMap(Double.init)
            trkptAlt = nil
            trkptTime = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "metadata":
            insideMetadata = false
        case "trk":
            insideTrack = false
        case "trkpt":
            if let lat = trkptLat, let lon = trkptLon, let time = trkptTime {
                points.append((lat, lon, trkptAlt ?? 0, time))
            }
            insideTrkpt = false
        case "name":
            if insideTrack && !insideTrkpt && name.isEmpty {
                name = value
            }
        case "keywords":
            if insideMetadata {
                tags = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        case "ele":
            if insideTrkpt { trkptAlt = Double(value) }
        case "time":
            if insideTrkpt { trkptTime = isoFormatter.date(from: value) }
        default:
            break
        }
        text = ""
    }
}
