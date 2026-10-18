import Foundation

/// Display / input unit. Volumes are always stored in whole millilitres.
enum VolumeUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case milliliters
    case fluidOunces

    static let mlPerOunce = 29.5735295625

    var id: Self { self }

    static var localeDefault: VolumeUnit {
        Locale.current.measurementSystem == .us ? .fluidOunces : .milliliters
    }

    var foundationUnit: UnitVolume {
        self == .milliliters ? .milliliters : .fluidOunces
    }

    /// Short localized symbol: "ml" / "fl oz".
    var symbol: String {
        switch self {
        case .milliliters:
            let formatter = MeasurementFormatter()
            formatter.unitStyle = .medium
            formatter.unitOptions = .providedUnit
            return formatter.string(from: UnitVolume.milliliters)
        case .fluidOunces:
            return String(localized: "fl oz")
        }
    }

    var allowsDecimal: Bool { self == .fluidOunces }

    /// Step for goal steppers, in ml (50 ml or 2 fl oz).
    var goalStepML: Int { self == .milliliters ? 50 : 59 }

    /// Rounds to a tidy value of this unit: 50 ml or a whole fl oz.
    func snapped(_ ml: Int) -> Int {
        switch self {
        case .milliliters: Int((Double(ml) / 50).rounded()) * 50
        case .fluidOunces: milliliters(from: value(fromML: ml).rounded())
        }
    }

    func value(fromML ml: Int) -> Double {
        self == .milliliters ? Double(ml) : Double(ml) / Self.mlPerOunce
    }

    func milliliters(from value: Double) -> Int {
        let ml = self == .milliliters ? value : value * Self.mlPerOunce
        return Int(ml.rounded())
    }
}

enum VolumeFormat {
    /// "250 ml", "8.5 fl oz". Ounces are formatted by hand: Foundation says "US fl oz".
    static func string(_ ml: Int, unit: VolumeUnit) -> String {
        switch unit {
        case .milliliters:
            return Measurement(value: Double(ml), unit: UnitVolume.milliliters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                        numberFormatStyle: numberStyle(unit)))
        case .fluidOunces:
            return String(localized: "\(number(ml, unit: unit)) fl oz")
        }
    }

    /// Just the number: "1,250" / "8.5".
    static func number(_ ml: Int, unit: VolumeUnit) -> String {
        unit.value(fromML: ml).formatted(numberStyle(unit))
    }

    /// Compact form for tight spaces: "1.2 L" for big ml values.
    static func compact(_ ml: Int, unit: VolumeUnit) -> String {
        guard unit == .milliliters, ml >= 1000 else { return string(ml, unit: unit) }
        return Measurement(value: Double(ml) / 1000, unit: UnitVolume.liters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }

    private static func numberStyle(_ unit: VolumeUnit) -> FloatingPointFormatStyle<Double> {
        unit == .milliliters
            ? .number.precision(.fractionLength(0))
            : .number.precision(.fractionLength(0...1))
    }
}

enum ProgressMath {
    /// Percent for display. Capped at 99 until the goal is truly reached,
    /// so 1999 of 2000 never reads as "100%".
    static func percent(total: Int, goal: Int) -> Int {
        guard goal > 0, total > 0 else { return 0 }
        let raw = Int((Double(total) / Double(goal) * 100).rounded())
        return total >= goal ? raw : min(99, raw)
    }

    static func fraction(total: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, max(0, Double(total) / Double(goal)))
    }
}

enum GoalCalculator {
    static let range = 1000...4500
    static let mlPerKg = 30.0
    static let kgPerPound = 0.45359237

    /// Common rule of thumb: ~30 ml per kg of body weight, rounded to 50 ml.
    static func suggestedML(weightKg: Double) -> Int {
        let raw = weightKg * mlPerKg
        let rounded = Int((raw / 50).rounded()) * 50
        return min(range.upperBound, max(range.lowerBound, rounded))
    }
}
