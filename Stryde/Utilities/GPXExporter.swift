import Foundation

enum GPXExporter {
    static func export(run: Run) -> String {
        let iso = ISO8601DateFormatter()
        let name = xmlEscape(run.name.isEmpty ? "Run" : run.name)

        let keywords = run.tags.isEmpty
            ? ""
            : "\n        <keywords>\(xmlEscape(run.tags.joined(separator: ", ")))</keywords>"

        let trackPoints = run.routePoints
            .sorted { $0.timestamp < $1.timestamp }
            .map { p in
                """
                      <trkpt lat="\(p.latitude)" lon="\(p.longitude)">
                        <ele>\(String(format: "%.1f", p.altitude))</ele>
                        <time>\(iso.string(from: p.timestamp))</time>
                      </trkpt>
                """
            }
            .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Stryde" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(name)</name>
            <time>\(iso.string(from: run.date))</time>\(keywords)
            <link href="stryde://id/\(run.id.uuidString)"><text>Stryde</text></link>
            <link href="stryde://duration/\(String(format: "%.3f", run.duration))"><text>Duration</text></link>
          </metadata>
          <trk>
            <name>\(name)</name>
            <trkseg>
        \(trackPoints)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
