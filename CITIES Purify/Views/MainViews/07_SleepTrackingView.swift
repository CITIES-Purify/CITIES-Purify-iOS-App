import SwiftUI

struct SleepTrackingView: View {
    var body: some View {
        SampleTypeTrackingView(
            sampleTypeId: "sleep",
            title: "Sleep Tracking",
            explanationHeader: Text("Why track your sleep?"),
            explanationContent: Text("""
                    To monitor sleep and other metrics like heart rate. This helps us **anonymously** analyze how purification may affect your sleep quality.
                    
                    **[IMPORTANT]** If you tracked sleep but still received the sleep reminder notification, it is because you haven't opened the app occasionally to sync data. Open it and you will see the updated info. Click **Force Sync Data** if you still see no data in the app.
                    """),
            explanationFooter: Text("""
                    **MAKE SURE TO:**
                    - Set up **Sleep Schedule** so the Watch is *automatically* in **Sleep Focus** every night. Sleep tracking only happens if **Sleep Focus** is on. You can also manually turn on **Sleep Focus** before bed.
                    - Make sure **Charging Reminders** is on (Sleep app). The Watch needs 30%+ battery before bedtime. A 30-min charge is enough!
                    """),
            textForLinkToGuie: "See Sleep Tracking Guide Again",
            onboardingViews: [
                AnyView(Onboarding_Sleep_1()),
                AnyView(Onboarding_Sleep_2()),
                AnyView(Onboarding_Sleep_3())
            ],
            trackingProgressHeader: Text("Sleep Tracking Progress by Week"),
            trackingProgressFooter: Text("""
                                        This chart summarizes which dates CITIES Purify receives your sleep data. To count for sleep tracking, each day needs 2+ hours of sleep. See the detailed Sleep data in the **Health app**, with sleep stages and timeframes.
                                        """)
        )
    }
}

