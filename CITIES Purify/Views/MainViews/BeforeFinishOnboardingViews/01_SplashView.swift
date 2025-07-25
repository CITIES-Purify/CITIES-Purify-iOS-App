import Foundation
import SwiftUI

public let cornerR = 10.0

struct SplashView: View {
    @EnvironmentObject var appState:AppState
    
    var body: some View {
        VStack {
            Spacer()
            Image("CITIES").resizable().scaledToFit().frame(width: 200, height: 200, alignment: .center).cornerRadius(10).padding()
            
            Text("CITIES Purify").font(.largeTitle.weight(.semibold))
            Text("Assessing the Health Impact of Indoor Air Purification Using Apple Watch Health Data")
                .font(Font.title3)
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            Button(action: {
                appState.currentView = .registration
            }) {
                HStack {
                    Text("Continue")
                        .font(.title3.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.title)
                }.padding()
                    .foregroundColor(/*@START_MENU_TOKEN@*/.white/*@END_MENU_TOKEN@*/)
                    .background(/*@START_MENU_TOKEN@*//*@PLACEHOLDER=View@*/Color("AccentColor")/*@END_MENU_TOKEN@*/)
                    .cornerRadius(CGFloat(cornerR))
            }
            Spacer()

        }
        .padding(.bottom)
    }
}
