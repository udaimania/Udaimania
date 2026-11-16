import SwiftUI
#if SCREEN_TIME_ENABLED
import FamilyControls
import DeviceActivity

struct UsageView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var picking = false
    @State private var status = "Not requested"
    @State private var showReport = false
    @State private var selectedOnly = true
    @State private var reportID = UUID()
    private var filter: DeviceActivityFilter {
        DeviceActivityFilter(segment: .hourly(during: DateInterval(start: Calendar.current.startOfDay(for: .now), end: .now)),
                             devices: .init([.iPhone]), applications: selectedOnly ? selection.applicationTokens : [])
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Apple-reported app time").font(.title2.bold())
                    Text("Report data stays inside Apple’s isolated extension. It is not copied to Capture Lab’s database, JSON export, or a server.")
                    Text(status).font(.callout).foregroundStyle(.secondary)
                    Button("Request individual Screen Time access") {
                        Task {
                            do {
                                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                                status = String(describing: AuthorizationCenter.shared.authorizationStatus)
                            } catch { status = "Authorization failed: \(error.localizedDescription)" }
                        }
                    }.buttonStyle(.borderedProminent)
                    Button("Choose Slack and mail apps") { picking = true }.buttonStyle(.bordered)
                    Text("\(selection.applicationTokens.count) apps selected. App selection cannot distinguish a work account from a personal account.")
                    Toggle("Only selected apps", isOn: $selectedOnly)
                    Button("Load / refresh today’s report") { showReport = true; reportID = UUID() }.buttonStyle(.bordered)
                    if showReport {
                        DeviceActivityReport(.init("UdaimaniaUsage"), filter: filter)
                            .id(reportID).frame(minHeight: 650)
                    }
                    Text("The report can be delayed or empty. Empty is not zero usage. Check the device name and last-updated timestamp; eligible iPhones may appear separately. Recheck after 5 and 15 minutes during a trial.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Usage")
                .familyActivityPicker(isPresented: $picking, selection: $selection)
                .onAppear {
                    if let data = UserDefaults.standard.data(forKey: "usageSelection"),
                       let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selection = saved }
                    status = String(describing: AuthorizationCenter.shared.authorizationStatus)
                }
                .onChange(of: selection) { _, value in
                    UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: "usageSelection")
                }
        }
    }
}
#else
struct UsageView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Separate Screen Time experiment") {
                    Text("This basic build runs the screen-capture and service-evidence tests without requesting Family Controls.")
                    Text("To test Apple-reported app durations, install the “Capture Lab + Screen Time” scheme using a signing team provisioned for Family Controls.")
                    Text("That build contains a Device Activity report extension. Its usage results stay inside the report; they are not silently exported.")
                }
                Section("What usage data can tell us") {
                    Text("Per-app duration and pickups can help compare Slack and mail with other phone use. They do not identify the workspace, mailbox, message read, or attention paid.")
                    Text("Missing or delayed reports remain unknown, not zero.")
                }
            }.navigationTitle("Usage")
        }
    }
}
#endif
