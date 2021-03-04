import SwiftUI

extension ISFEditor {
    class ViewModel<Provider>: BaseViewModel<Provider>, ObservableObject where Provider: ISFEditorProvider {
        @Injected() var settingsManager: SettingsManager!
        @Published var items: [Item] = []

        let timeValues = stride(from: 0.0, to: 1.days.timeInterval, by: 30.minutes.timeInterval).map { $0 }

        var rateValues: [Double] {
            switch units {
            case .mgdL:
                return stride(from: 9, to: 540.01, by: 1.0).map { $0 }
            case .mmolL:
                return stride(from: 0.5, to: 30.01, by: 0.1).map { $0 }
            }
        }

        var canAdd: Bool {
            guard let lastItem = items.last else { return true }
            return lastItem.timeIndex < timeValues.count - 1
        }

        private(set) var units: GlucoseUnits = .mmolL

        override func subscribe() {
            units = settingsManager.settings.units
            let profile = provider.profile
            items = profile.sensitivities.map { value in
                let timeIndex = timeValues.firstIndex(of: Double(value.offset * 60)) ?? 0
                let rateIndex = rateValues.firstIndex(of: Double(value.sensitivity)) ?? 0
                return Item(rateIndex: rateIndex, selectedIndex: timeIndex)
            }
        }

        func add() {
            var selected = 0
            var rate = 0
            if let last = items.last {
                selected = last.timeIndex + 1
                rate = last.rateIndex
            }

            let newItem = Item(rateIndex: rate, selectedIndex: selected)

            items.append(newItem)
        }

        func save() {
            let sensitivities = items.enumerated().map { _, item -> InsulinSensitivityEntry in
                let fotmatter = DateFormatter()
                fotmatter.timeZone = TimeZone(secondsFromGMT: 0)
                fotmatter.dateFormat = "HH:mm:ss"
                let date = Date(timeIntervalSince1970: self.timeValues[item.timeIndex])
                let minutes = Int(date.timeIntervalSince1970 / 60)
                let rate = Decimal(self.rateValues[item.rateIndex])
                return InsulinSensitivityEntry(sensitivity: rate, offset: minutes, start: fotmatter.string(from: date))
            }
            let profile = InsulinSensitivities(units: units, userPrefferedUnits: units, sensitivities: sensitivities)
            provider.saveProfile(profile)
        }

        func validate() {
            DispatchQueue.main.async {
                let uniq = Array(Set(self.items))
                let sorted = uniq.sorted { $0.timeIndex < $1.timeIndex }
                sorted.first?.timeIndex = 0
                self.items = sorted
            }
        }
    }
}