import SwiftUI

struct MainView: View {
    enum Tab {
        case study
        case record
        case myPage
    }

    @State private var selectedTab: Tab = .study

    var body: some View {
        TabView(selection: $selectedTab) {
            StudyHomeView()
                .tabItem {
                    Label("学習", systemImage: "books.vertical.fill")
                }
                .tag(Tab.study)

            StudyRecordView()
                .tabItem {
                    Label("学習記録", systemImage: "chart.bar.xaxis")
                }
                .tag(Tab.record)

            MyPageView()
                .tabItem {
                    Label("マイページ", systemImage: "person.fill")
                }
                .tag(Tab.myPage)
        }
        .tint(Color("main"))
    }
}

#Preview {
    MainView()
        .environment(AppState.shared)
}
