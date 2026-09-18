package org.rikako.quiz

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.ui.account.AccountScreen
import org.rikako.quiz.ui.onboarding.OnboardingScreen
import org.rikako.quiz.ui.mypage.MyPageScreen
import org.rikako.quiz.ui.mypage.MyPageViewModel
import org.rikako.quiz.ui.mypage.ProfileScreen
import org.rikako.quiz.ui.mypage.SettingsScreen
import org.rikako.quiz.ui.mypage.NotificationsScreen
import org.rikako.quiz.ui.mypage.HelpScreen
import org.rikako.quiz.ui.mypage.TransferScreen
import org.rikako.quiz.ui.quiz.QuizMode
import org.rikako.quiz.ui.quiz.QuizScreen
import org.rikako.quiz.ui.record.StudyRecordScreen
import org.rikako.quiz.ui.root.RootScreen
import org.rikako.quiz.ui.theme.RikakoTheme
import org.rikako.quiz.ui.workbook.WorkbookDetailScreen
import org.rikako.quiz.ui.workbook.WorkbookListScreen
import org.rikako.quiz.ui.wrong.WrongAnswersScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // ライトテーマ固定なので、システムバーのアイコンも明るい背景向けに固定する。
        // 端末がダークのときに enableEdgeToEdge() の既定へ任せると、白背景に白アイコンになる。
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(TRANSPARENT_BAR, TRANSPARENT_BAR),
            navigationBarStyle = SystemBarStyle.light(TRANSPARENT_BAR, TRANSPARENT_BAR),
        )
        super.onCreate(savedInstanceState)
        CrashReporter.crashIfRequested(intent?.extras)
        setContent {
            var transferRevision by rememberSaveable { mutableIntStateOf(0) }
            RikakoTheme {
                RootScreen { refreshRoot ->
                    val hasCompletedOnboarding by ServiceLocator.onboardingStore.completed.collectAsStateWithLifecycle()
                    if (hasCompletedOnboarding) {
                        // 引き継ぎ後は nav entry と教材 ViewModel を作り直して、旧端末の選択を残さない。
                        key(transferRevision) {
                            RikakoApp(onTransferred = {
                                transferRevision++
                                refreshRoot()
                            })
                        }
                    } else OnboardingScreen()
                }
            }
        }
    }
}

/** システムバーは背景を透過させ、コンテンツ側の色を見せる。 */
private const val TRANSPARENT_BAR = 0x00FFFFFF

private object Routes {
    const val WORKBOOK_LIST = "workbooks"
    const val STUDY_RECORD = "study-record"
    const val WRONG_ANSWERS = "wrong-answers"
    const val ACCOUNT = "account"
    const val MY_PAGE = "my-page"
    const val PROFILE = "profile"
    const val SETTINGS = "settings"
    const val NOTIFICATIONS = "notifications"
    const val HELP = "help"
    const val TRANSFER = "transfer"
    const val WORKBOOK_DETAIL = "workbooks/{workbookId}"
    const val QUIZ = "quiz/{workbookId}/{sectionIndex}"
    const val REVIEW_QUIZ = "quiz/review"

    fun workbookDetail(id: Long) = "workbooks/$id"

    fun quiz(id: Long, sectionIndex: Int) = "quiz/$id/$sectionIndex"
}

private enum class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    Workbooks(Routes.WORKBOOK_LIST, "学習", Icons.AutoMirrored.Filled.List),
    StudyRecord(Routes.STUDY_RECORD, "学習記録", Icons.Filled.DateRange),
    MyPage(Routes.MY_PAGE, "マイページ", Icons.Filled.Person),
}

@Composable
private fun RikakoApp(onTransferred: () -> Unit) {
    val navController = rememberNavController()
    val myPageViewModel: MyPageViewModel = viewModel(factory = MyPageViewModel.factory())
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination

    // 問題を解いている間はタブを出さない（誤操作で解答が失われるのを防ぐ）。
    val showBottomBar = TopLevelDestination.entries.any { destination ->
        currentDestination?.hierarchy?.any { it.route == destination.route } == true
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        bottomBar = {
            if (showBottomBar) {
                BottomBar(navController = navController, currentDestination = currentDestination)
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Routes.WORKBOOK_LIST,
            modifier = Modifier.fillMaxSize(),
        ) {
            composable(Routes.WORKBOOK_LIST) {
                WorkbookListScreen(
                    modifier = Modifier.padding(padding),
                    onChapterClick = { id, sectionIndex ->
                        navController.navigate(Routes.quiz(id, sectionIndex))
                    },
                )
            }
            composable(Routes.STUDY_RECORD) {
                StudyRecordScreen(
                    modifier = Modifier.padding(padding),
                    onWrongAnswers = { navController.navigate(Routes.WRONG_ANSWERS) },
                )
            }
            composable(Routes.WRONG_ANSWERS) {
                WrongAnswersScreen(
                    modifier = Modifier.padding(padding),
                    onStartReview = { navController.navigate(Routes.REVIEW_QUIZ) },
                    onBack = navController::popBackStack,
                )
            }
            composable(Routes.REVIEW_QUIZ) {
                QuizScreen(mode = QuizMode.Review, onFinish = navController::popBackStack)
            }
            composable(Routes.ACCOUNT) {
                AccountScreen(onBack = navController::popBackStack)
            }
            composable(Routes.MY_PAGE) {
                MyPageScreen(
                    modifier = Modifier.padding(padding),
                    viewModel = myPageViewModel,
                    onProfile = { navController.navigate(Routes.PROFILE) },
                    onSettings = { navController.navigate(Routes.SETTINGS) },
                    onNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onHelp = { navController.navigate(Routes.HELP) },
                )
            }
            composable(Routes.PROFILE) {
                ProfileScreen(
                    onBack = navController::popBackStack,
                    onAccount = { navController.navigate(Routes.ACCOUNT) },
                    onTransfer = { navController.navigate(Routes.TRANSFER) },
                    viewModel = myPageViewModel,
                )
            }
            composable(Routes.SETTINGS) {
                SettingsScreen(
                    onBack = navController::popBackStack,
                    onAccount = { navController.navigate(Routes.ACCOUNT) },
                    onNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                )
            }
            composable(Routes.NOTIFICATIONS) {
                NotificationsScreen(onBack = navController::popBackStack, viewModel = myPageViewModel)
            }
            composable(Routes.HELP) {
                HelpScreen(onBack = navController::popBackStack)
            }
            composable(Routes.TRANSFER) {
                TransferScreen(
                    onBack = navController::popBackStack,
                    onAccount = { navController.navigate(Routes.ACCOUNT) },
                    onTransferred = {
                        // この ViewModel は Activity スコープなので、nav を作り直すだけでは残る。
                        myPageViewModel.refresh()
                        onTransferred()
                    },
                )
            }
            composable(
                route = Routes.WORKBOOK_DETAIL,
                arguments = listOf(navArgument("workbookId") { type = NavType.LongType }),
            ) { entry ->
                val workbookId = entry.arguments?.getLong("workbookId") ?: return@composable
                WorkbookDetailScreen(
                    workbookId = workbookId,
                    onBack = navController::popBackStack,
                    onStartQuiz = { sectionIndex ->
                        navController.navigate(Routes.quiz(workbookId, sectionIndex))
                    },
                )
            }
            composable(
                route = Routes.QUIZ,
                arguments = listOf(
                    navArgument("workbookId") { type = NavType.LongType },
                    navArgument("sectionIndex") { type = NavType.IntType },
                ),
            ) { entry ->
                val workbookId = entry.arguments?.getLong("workbookId") ?: return@composable
                val sectionIndex = entry.arguments?.getInt("sectionIndex") ?: return@composable
                QuizScreen(
                    mode = QuizMode.Workbook(workbookId, sectionIndex),
                    onFinish = navController::popBackStack,
                )
            }
        }
    }
}

@Composable
private fun BottomBar(
    navController: NavHostController,
    currentDestination: androidx.navigation.NavDestination?,
) {
    NavigationBar(containerColor = Color.White) {
        TopLevelDestination.entries.forEach { destination ->
            val selected = currentDestination?.hierarchy?.any { it.route == destination.route } == true
            NavigationBarItem(
                selected = selected,
                onClick = {
                    navController.navigate(destination.route) {
                        // タブを行き来してもバックスタックが積み上がらないようにする。
                        popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                icon = { Icon(destination.icon, contentDescription = destination.label) },
                label = { Text(destination.label) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = Color(0xFF48AC01),
                    selectedTextColor = Color(0xFF368600),
                    indicatorColor = Color(0xFFEDF7E6),
                    unselectedIconColor = Color(0xFF777B76),
                    unselectedTextColor = Color(0xFF777B76),
                ),
            )
        }
    }
}
