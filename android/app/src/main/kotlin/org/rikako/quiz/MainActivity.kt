package org.rikako.quiz

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
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
import org.rikako.quiz.ui.account.AccountScreen
import org.rikako.quiz.ui.quiz.QuizScreen
import org.rikako.quiz.ui.record.StudyRecordScreen
import org.rikako.quiz.ui.theme.RikakoTheme
import org.rikako.quiz.ui.workbook.WorkbookDetailScreen
import org.rikako.quiz.ui.workbook.WorkbookListScreen
import org.rikako.quiz.ui.wrong.WrongAnswersScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            RikakoTheme {
                RikakoApp()
            }
        }
    }
}

private object Routes {
    const val WORKBOOK_LIST = "workbooks"
    const val STUDY_RECORD = "study-record"
    const val WRONG_ANSWERS = "wrong-answers"
    const val ACCOUNT = "account"
    const val WORKBOOK_DETAIL = "workbooks/{workbookId}"
    const val QUIZ = "quiz/{workbookId}"

    fun workbookDetail(id: Long) = "workbooks/$id"

    fun quiz(id: Long) = "quiz/$id"
}

private enum class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    Workbooks(Routes.WORKBOOK_LIST, "問題集", Icons.AutoMirrored.Filled.List),
    StudyRecord(Routes.STUDY_RECORD, "学習記録", Icons.Filled.DateRange),
    WrongAnswers(Routes.WRONG_ANSWERS, "間違えた問題", Icons.Filled.Refresh),
    Account(Routes.ACCOUNT, "アカウント", Icons.Filled.Person),
}

@Composable
private fun RikakoApp() {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination

    // 問題を解いている間はタブを出さない（誤操作で解答が失われるのを防ぐ）。
    val showBottomBar = TopLevelDestination.entries.any { destination ->
        currentDestination?.hierarchy?.any { it.route == destination.route } == true
    }

    Scaffold(
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
                    onWorkbookClick = { id -> navController.navigate(Routes.workbookDetail(id)) },
                )
            }
            composable(Routes.STUDY_RECORD) {
                StudyRecordScreen(modifier = Modifier.padding(padding))
            }
            composable(Routes.WRONG_ANSWERS) {
                WrongAnswersScreen(modifier = Modifier.padding(padding))
            }
            composable(Routes.ACCOUNT) {
                AccountScreen(modifier = Modifier.padding(padding))
            }
            composable(
                route = Routes.WORKBOOK_DETAIL,
                arguments = listOf(navArgument("workbookId") { type = NavType.LongType }),
            ) { entry ->
                val workbookId = entry.arguments?.getLong("workbookId") ?: return@composable
                WorkbookDetailScreen(
                    workbookId = workbookId,
                    onBack = navController::popBackStack,
                    onStartQuiz = { navController.navigate(Routes.quiz(workbookId)) },
                )
            }
            composable(
                route = Routes.QUIZ,
                arguments = listOf(navArgument("workbookId") { type = NavType.LongType }),
            ) { entry ->
                val workbookId = entry.arguments?.getLong("workbookId") ?: return@composable
                QuizScreen(workbookId = workbookId, onFinish = navController::popBackStack)
            }
        }
    }
}

@Composable
private fun BottomBar(
    navController: NavHostController,
    currentDestination: androidx.navigation.NavDestination?,
) {
    NavigationBar {
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
            )
        }
    }
}
