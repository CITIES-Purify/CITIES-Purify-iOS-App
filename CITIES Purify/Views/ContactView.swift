import SwiftUI

struct ResearchTeamMember {
    let name: String
    let role: String
    let email: String
}

struct ContactView: View {
    let researchTeam = [
        ResearchTeamMember(name: "John Doe", role: "Principal Investigator", email: "john.doe@uni.edu")
    ]
    
    var body: some View {
        List {
            Section(
                header: Text("Contact Us"),
                footer: Text("For questions about your rights as a research participant, you may contact the Institutional Review Board, irb@uni.edu.")
            ) {
                VStack(alignment: .leading) {
                    // List of people
                    ForEach(researchTeam, id: \.name) { person in
                        VStack(alignment: .leading) {
                            Text(person.name)
                                .font(.headline)
                            Text(person.role)
                                .foregroundColor(.gray)
                            Text(person.email)
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    if let url = URL(string: "mailto:\(person.email)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContactView()
}
