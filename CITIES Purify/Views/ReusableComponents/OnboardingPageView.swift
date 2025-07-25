import SwiftUI

enum OnboardingImage {
    case none
    case single(String)
    case multiple([String])
}

struct OnboardingPageView: View {
    let title: String
    let image: OnboardingImage
    let content: AnyView
    
    init(title: String, image: OnboardingImage = .none, content: AnyView) {
        self.title = title
        self.image = image
        self.content = content
        
        // Customize dots (only affects views using PageTabViewStyle)
        UIPageControl.appearance().currentPageIndicatorTintColor = .accent
        UIPageControl.appearance().pageIndicatorTintColor = .gray
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title.weight(.bold))
            
            Spacer()
            
            ZStack {
                ScrollView {
                    VStack {
                        Group {
                            switch image {
                            case .none:
                                EmptyView()
                            case .single(let imageName):
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 300)
                            case .multiple(let imageArray):
                                TabView {
                                    ForEach(imageArray, id: \.self) { imageName in
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: 300)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle())
                                .frame(height: 380)
                            }
                        }
                        
                        content
                            .padding(.bottom, 60) // Extra space for gradient visibility
                    }
                }
                
                // Gradient at the bottom to suggest more content
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color(uiColor: UIColor.systemBackground).opacity(0.8),
                            Color(uiColor: UIColor.systemBackground)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
