import Foundation

public struct SunSample: Sendable {
    public let elevation: Int
    public let westward: Bool

    public init(elevation: Int, westward: Bool) {
        self.elevation = elevation
        self.westward = westward
    }
}

/// Crude solar model for Frankfurt in summer, elevation peaking early
/// afternoon — enough to drive the UI honestly until real ephemeris and the
/// LoD2 shadow index land (BEM-D02/D03).
public enum SunModel {
    public static let dayStart: Double = 330  // 05:30
    public static let dayEnd: Double = 1290  // 21:30
    /// Solar noon of the model (13:20) — elevation peaks, shadows flip east.
    public static let peakMinutes: Double = 800
    /// Peak elevation in degrees; also normalizes the scrubber curve.
    public static let peakElevation: Double = 58

    public static func sample(atMinutes minutes: Double) -> SunSample {
        let t = (minutes - peakMinutes) / 470
        let elevation = max(2, Int((peakElevation * (1 - t * t)).rounded()))
        return SunSample(elevation: elevation, westward: minutes < peakMinutes)
    }

    public static func clockLabel(minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Now, clamped into the modeled day.
    public static func nowMinutes(_ date: Date = .now, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let mins = Double((parts.hour ?? 12) * 60 + (parts.minute ?? 0))
        return min(max(mins, dayStart), dayEnd)
    }
}
