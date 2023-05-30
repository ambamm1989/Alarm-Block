import SwiftUI

// Define your alarm struct and an observable object to manage your alarms
struct Alarm: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var startTime: Date
    var endTime: Date
}

class AlarmData: ObservableObject {
    @Published var alarms = [Alarm]() {
        didSet {
            saveAlarms()
        }
    }

    let defaults = UserDefaults.standard

    init() {
        loadAlarms()
    }

    func saveAlarms() {
        if let encodedData = try? JSONEncoder().encode(alarms) {
            defaults.set(encodedData, forKey: "SavedAlarms")
        }
    }

    func loadAlarms() {
        if let savedAlarms = defaults.object(forKey: "SavedAlarms") as? Data {
            if let decodedAlarms = try? JSONDecoder().decode([Alarm].self, from: savedAlarms) {
                alarms = decodedAlarms
            }
        }
    }
}


struct ContentView: View {
    var body: some View {
        NavigationView {
            AlarmListView()
        }
        .navigationTitle("Saved Alarms")
        .navigationBarItems(trailing: addAlarmButton)
        .navigationViewStyle(StackNavigationViewStyle()) // Use StackNavigationViewStyle for iPad
        .environmentObject(AlarmData())
    }
    
    var addAlarmButton: some View {
        NavigationLink(destination: AlarmFormView()) {
            Text("Add")
        }
    }
}



struct AlarmListView: View {
    @EnvironmentObject var alarmData: AlarmData
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }
    
    var sortedAlarms: [Alarm] {
        alarmData.alarms.sorted { alarm1, alarm2 in
            alarm1.startTime < alarm2.startTime
        }
    }
    
    var body: some View {
        List {
            ForEach(sortedAlarms) { alarm in
                NavigationLink(destination: AlarmFormView(alarm: alarm)) {
                    VStack(alignment: .leading) {
                        Text(alarm.title)
                            .font(.headline)
                        Text("\(formattedTime(alarm.startTime)) - \(formattedTime(alarm.endTime))")
                            .font(.subheadline)
                    }
                }
            }
            .onDelete(perform: deleteAlarm) // Enable deletion by swipe gesture
        }
        .navigationTitle("Saved Alarms")
        .navigationBarItems(trailing: addAlarmButton)
    }
    
    var addAlarmButton: some View {
        NavigationLink(destination: AlarmFormView()) {
            Text("Add")
        }
    }
    
    func deleteAlarm(at offsets: IndexSet) {
        alarmData.alarms.remove(atOffsets: offsets)
    }
    
    func formattedTime(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

struct PresetAlarmView: View {
    @EnvironmentObject var alarmData: AlarmData
    @Environment(\.presentationMode) var presentationMode
    
    let presets = [
        ("Morning Alarm", "Wake up for the day", 7, 0, 7, 30),
        ("Lunch Alarm", "Reminder to eat lunch", 12, 0, 12, 30),
        ("Evening Alarm", "End of the day", 18, 0, 18, 30)
    ]
    
    var body: some View {
        List {
            ForEach(presets, id: \.0) { preset in
                Button(action: {
                    let title = preset.0
                    let description = preset.1
                    let startHour = preset.2
                    let startMinute = preset.3
                    let endHour = preset.4
                    let endMinute = preset.5
                    
                    let calendar = Calendar.current
                    var startComponents = DateComponents()
                    startComponents.hour = startHour
                    startComponents.minute = startMinute
                    let startTime = calendar.date(from: startComponents)!
                    
                    var endComponents = DateComponents()
                    endComponents.hour = endHour
                    endComponents.minute = endMinute
                    let endTime = calendar.date(from: endComponents)!
                    
                    let alarm = Alarm(title: title, description: description, startTime: startTime, endTime: endTime)
                    alarmData.alarms.append(alarm)
                    
                    // Dismiss the view after adding the preset alarm
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(preset.0)
                            .font(.headline)
                        Text(preset.1)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Select a Preset")
    }
}



struct AlarmFormView: View {
    @EnvironmentObject var alarmData: AlarmData
    @Environment(\.presentationMode) var presentationMode
    
    @State var alarm: Alarm?
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var startNotificationMessage: String = "Your start alarm is going off!"
    @State private var endNotificationMessage: String = "Your end alarm is going off!"
    @State private var showError: Bool = false
    @State private var repeats: Bool = false
    
    func scheduleNotification(hour: Int, minute: Int, title: String, body: String, repeats: Bool) {
        // Request authorization for notifications
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            // Enable or disable features based on authorization.
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = UNNotificationSound.default
                
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
    
    
    var body: some View {
        Form {
            Section(header: Text("Alarm Details")) {
                TextField("Title", text: $title)
                TextField("Description", text: $description)
            }
            Section(header: Text("Time")) {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            Section(header: Text("Repeat")) {
                Toggle("Repeat Daily", isOn: $repeats)
            }
            Section(header: Text("Notification Messages")) {
                TextField("Start Time Notification Message", text: $startNotificationMessage)
                TextField("End Time Notification Message", text: $endNotificationMessage)
            }
            Section {
                Button("Save Alarm") {
                    let calendar = Calendar.current
                    let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                    let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                    
                    if let startHour = startComponents.hour, let startMinute = startComponents.minute,
                       let endHour = endComponents.hour, let endMinute = endComponents.minute {
                        
                        if startHour < endHour || (startHour == endHour && startMinute < endMinute) || endHour < startHour {
                            // Valid time range
                            if let alarm = alarm {
                                // Edit existing alarm
                                if let index = alarmData.alarms.firstIndex(where: { $0.id == alarm.id }) {
                                    alarmData.alarms[index].title = title
                                    alarmData.alarms[index].description = description
                                    alarmData.alarms[index].startTime = startTime
                                    alarmData.alarms[index].endTime = endTime
                                }
                            } else {
                                // Create new alarm
                                let newAlarm = Alarm(title: title, description: description, startTime: startTime, endTime: endTime)
                                alarmData.alarms.append(newAlarm)
                            }
                            
                            // Schedule a notification for the start time
                            scheduleNotification(hour: startHour, minute: startMinute, title: "Start Alarm", body: startNotificationMessage, repeats: true)
                            
                            // Schedule a notification for the end time
                            scheduleNotification(hour: endHour, minute: endMinute, title: "End Alarm", body: endNotificationMessage, repeats: true)
                            
                            // Dismiss the view after saving the alarm
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            // Show warning if start time is not before the end time
                            showError = true
                        }
                    }
                }
            }
            
            .onAppear {
                if let alarm = alarm {
                    title = alarm.title
                    description = alarm.description
                    startTime = alarm.startTime
                    endTime = alarm.endTime
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Invalid Time"),
                    message: Text("Please select a start time that is before the end time."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
        
        struct ContentView_Previews: PreviewProvider {
            static var previews: some View {
                ContentView().environmentObject(AlarmData())
            }
        }
    

    
