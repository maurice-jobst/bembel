import BEMBELKit
import SwiftUI

/// What the Sonnenstand numbers promise, and what they do not (BEM-D06).
///
/// The screen shows a clock to the minute and an angle to the degree. Both
/// look like measurements and are arithmetic. That difference matters at
/// exactly one place: **the computed sunset is not the moment the sun goes
/// away where you are standing.** Somebody planning a terrace around it and
/// then watching the sun vanish behind the Taunus twenty minutes early would
/// be right to think the app is broken.
///
/// Every claim on this screen is checkable against the code or the tests, and
/// the numbers at the top are computed live rather than written down — a
/// disclosure that does the sum it is talking about ages better than prose.
struct SunAccuracyView: View {
    let day: Date
    let daylight: (sunrise: Double, sunset: Double)?
    let solarNoonMinutes: Double
    let refractionLift: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let daylight {
                        LabeledContent("sun.accuracy.sunrise") {
                            Text(verbatim: SunModel.clockLabel(minutes: daylight.sunrise))
                                .monospacedDigit()
                        }
                        LabeledContent("sun.accuracy.noon") {
                            Text(verbatim: SunModel.clockLabel(minutes: solarNoonMinutes))
                                .monospacedDigit()
                        }
                        LabeledContent("sun.accuracy.sunset") {
                            Text(verbatim: SunModel.clockLabel(minutes: daylight.sunset))
                                .monospacedDigit()
                        }
                    } else {
                        // Frankfurt never reaches this, but the model can, and
                        // a screen about honesty should not hide the case.
                        Text("sun.accuracy.nodaylight")
                            .foregroundStyle(BEMColor.inkSecondary)
                    }
                } header: {
                    Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                } footer: {
                    Text("sun.accuracy.computed.footer")
                }

                Section {
                    Text("sun.accuracy.source.body")
                } header: {
                    Text("sun.accuracy.source.header")
                }

                Section {
                    Text("sun.accuracy.precision.body")
                } header: {
                    Text("sun.accuracy.precision.header")
                }

                Section {
                    Text("sun.accuracy.horizon.body")
                    LabeledContent("sun.accuracy.refraction.now") {
                        Text(verbatim: Self.degrees(refractionLift))
                            .monospacedDigit()
                    }
                } header: {
                    Text("sun.accuracy.horizon.header")
                } footer: {
                    Text("sun.accuracy.refraction.footer")
                }

                // The section the rest of the screen exists to reach.
                Section {
                    limit("mountain.2", "sun.accuracy.limit.horizon")
                    limit("thermometer.medium", "sun.accuracy.limit.atmosphere")
                    limit("mappin.and.ellipse", "sun.accuracy.limit.location")
                } header: {
                    Text("sun.accuracy.limits.header")
                }
            }
            .navigationTitle("sun.accuracy.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }

    private func limit(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(BEMColor.cobalt)
        }
    }

    /// "0,57°" — two decimals, because the whole point of showing it is that
    /// the number is small and not zero.
    private static func degrees(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: value as NSNumber) ?? "—") + "°"
    }
}
