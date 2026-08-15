import Foundation

/// The Stadtzustand screen reads one protocol but three unrelated sources:
/// PEGELONLINE for the Main level (BEM-G01, live here), HLNUG for air quality
/// (BEM-G02) and NINA for warnings (BEM-G03). This composes what exists.
///
/// **Known limitation, and the reason it is written down rather than hidden:**
/// `CityStatus` is one value, so a PEGELONLINE outage currently fails the whole
/// screen — including the warning card, which is the one that matters most in
/// an emergency. That is tolerable only while the warning is still sample data.
/// Before BEM-G03 makes warnings real, `CityStatus` needs per-source states so
/// one dead source cannot blank the others — the same split `PlacesModel` made
/// for its two registers.
public struct LiveCityStatusProvider: CityStatusProviding {
    private let gauge: PegelOnlineProvider

    public init(gauge: PegelOnlineProvider = PegelOnlineProvider()) {
        self.gauge = gauge
    }

    public func status() async throws -> CityStatus {
        let reading = try await gauge.reading()
        let placeholder = SampleCityStatusProvider.status
        return CityStatus(
            // Still fabricated: temperature has no ticket, air is BEM-G02 and
            // the warning is BEM-G03.
            temperatureLabel: placeholder.temperatureLabel,
            warning: placeholder.warning,
            gauge: reading,
            airValues: placeholder.airValues,
            airStampLabel: placeholder.airStampLabel
        )
    }
}
