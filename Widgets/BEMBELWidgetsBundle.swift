import SwiftUI
import WidgetKit

@main
struct BEMBELWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DeparturesWidget()
        NearestCandidateWidget()
    }
}
