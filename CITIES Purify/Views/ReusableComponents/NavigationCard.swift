import SwiftUI

struct NavigationCard: View {
    let title: String
    let subtitle: Text
    let titleColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.weight(.semibold))
                .foregroundColor(titleColor)
                .multilineTextAlignment(.leading)
            
            subtitle
                .font(.body.weight(.medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
        }
    }
}
