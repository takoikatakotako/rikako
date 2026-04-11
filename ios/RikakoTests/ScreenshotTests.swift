import XCTest
import SwiftUI
@testable import Rikako

final class ScreenshotTests: XCTestCase {

    private let size = CGSize(width: 393, height: 852) // iPhone 15 Pro

    @MainActor
    private func makeStudyStore() -> StudyStore {
        StudyStore.shared
    }

    // MARK: - オンボーディング

    @MainActor
    func test01_Welcome() throws {
        let view = OnboardingView()
            .environment(makeStudyStore())
        takeScreenshot(view: view, name: "01_welcome")
    }

    // MARK: - 認証

    @MainActor
    func test02_Login() throws {
        let view = LoginView()
            .environment(makeStudyStore())
        takeScreenshot(view: view, name: "02_login")
    }

    @MainActor
    func test03_SignUp() throws {
        let view = NavigationStack {
            SignUpView(isLoggedIn: .constant(false))
        }
        takeScreenshot(view: view, name: "03_signup")
    }

    // MARK: - メイン

    @MainActor
    func test04_WorkbookList() throws {
        let view = NavigationStack {
            WorkbookListView()
        }
        takeScreenshot(view: view, name: "04_workbook_list")
    }

    @MainActor
    func test05_WorkbookDetail() throws {
        let view = NavigationStack {
            WorkbookDetailView(workbookID: 1)
        }
        takeScreenshot(view: view, name: "05_workbook_detail")
    }

    @MainActor
    func test06_Quiz() throws {
        let view = NavigationStack {
            QuizView(
                questions: MockData.questions,
                workbookTitle: "物質のすがた",
                workbookId: 1
            )
        }
        takeScreenshot(view: view, name: "06_quiz")
    }

    @MainActor
    func test07_Result() throws {
        let view = NavigationStack {
            ResultView(
                questions: MockData.questions,
                answers: [0, 1, 2, 1, 2],
                workbookTitle: "物質のすがた",
                workbookId: 1
            )
        }
        .environment(makeStudyStore())
        takeScreenshot(view: view, name: "07_result")
    }

    // MARK: - 設定

    @MainActor
    func test08_Settings() throws {
        let view = NavigationStack {
            SettingsView()
        }
        .environment(makeStudyStore())
        takeScreenshot(view: view, name: "08_settings")
    }

    @MainActor
    func test09_Profile() throws {
        let view = NavigationStack {
            ProfileView()
        }
        .environment(makeStudyStore())
        takeScreenshot(view: view, name: "09_profile")
    }

    // MARK: - Helper

    @MainActor
    private func takeScreenshot<V: View>(view: V, name: String) {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
