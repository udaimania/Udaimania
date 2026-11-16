import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import ExtensionKit

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        UsageScene { configuration in UsageReportView(configuration: configuration) }
    }
}

nonisolated struct UsageRow: Identifiable {
    let id = UUID()
    var token: ApplicationToken?
    var name: String
    var seconds: Double
    var pickups: Int
}
nonisolated struct DeviceUsage: Identifiable {
    let id = UUID()
    var name: String
    var lastUpdated: Date
    var seconds: Double
    var rows: [UsageRow]
}
nonisolated struct UsageConfiguration { var devices: [DeviceUsage] }

nonisolated struct UsageScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("UdaimaniaUsage")
    let content: (UsageConfiguration) -> UsageReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageConfiguration {
        var devices: [DeviceUsage] = []
        for await deviceData in data {
            var rows: [Application: UsageRow] = [:]
            var total: Double = 0
            for await segment in deviceData.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        var row = rows[app.application] ?? UsageRow(token: app.application.token,
                            name: app.application.localizedDisplayName ?? "Application", seconds: 0, pickups: 0)
                        row.seconds += app.totalActivityDuration; row.pickups += app.numberOfPickups
                        rows[app.application] = row
                    }
                }
            }
            devices.append(.init(name: deviceData.device.name ?? "Unnamed iPhone",
                                 lastUpdated: deviceData.lastUpdatedDate, seconds: total,
                                 rows: rows.values.sorted { $0.seconds > $1.seconds }))
        }
        return UsageConfiguration(devices: devices)
    }
}

nonisolated struct UsageReportView: View {
    var configuration: UsageConfiguration
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if configuration.devices.isEmpty {
                    Text("No report data returned").font(.headline)
                    Text("This is not a measurement of zero use. Check authorization and retry later.")
                }
                ForEach(configuration.devices) { device in
                    Text(device.name).font(.headline)
                    Text("Updated \(device.lastUpdated.formatted(date: .abbreviated, time: .standard))").font(.caption)
                    if device.rows.isEmpty {
                        Text("No application rows returned for this device and filter. Do not interpret this as zero use.").font(.caption)
                    }
                    Text(String(format: "Reported duration for this filter: %.1f min", device.seconds / 60))
                    ForEach(device.rows) { row in
                        HStack {
                            if let token = row.token { Label(token) } else { Text(row.name) }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(String(format: "%.1f min", row.seconds / 60))
                                Text("\(row.pickups) pickups").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                }
                Text("App-level measurement only. Work/personal account identity and reading attention are not available here.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
    }
}
