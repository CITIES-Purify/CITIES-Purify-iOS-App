import SwiftUI

struct ForceSyncButton: View {
    var body: some View {
        Button(action: {
            HealthStore.shared.collectDataForAllTypes(isLongRunning: false)
        }) {
            HStack(spacing: 6){
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                Text("Force Sync Data")
            }.font(.body.weight(.medium))
        }
    }
}
