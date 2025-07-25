import SwiftUI

struct NextButton: View{
    @EnvironmentObject var appState: AppState
    var toView: CurrentView!
    
    var body: some View{
        HStack(){
            Spacer()
            Button {
                if toView == .main{
                    // Save key that user has finished the onboarding experience to proceed to HomeView
                    UserDefaults.standard.set(true, forKey: "hasOnboarded")
                    appState.hasOnboarded = true
                }
                    appState.currentView = toView
            } label: {
                Image(systemName: "chevron.right")
                    .font(/*@START_MENU_TOKEN@*/.largeTitle/*@END_MENU_TOKEN@*/).frame(width: 75, height: 75)
            }
            
            .foregroundColor(Color.white).font(.caption).background(/*@START_MENU_TOKEN@*//*@PLACEHOLDER=View@*/Color("AccentColor")/*@END_MENU_TOKEN@*/)
            .cornerRadius(/*@START_MENU_TOKEN@*/100.0/*@END_MENU_TOKEN@*/)
        }
    }
}
