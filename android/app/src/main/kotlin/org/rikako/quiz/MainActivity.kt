package org.rikako.quiz

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import org.rikako.quiz.ui.theme.RikakoTheme
import org.rikako.quiz.ui.workbook.WorkbookDetailScreen
import org.rikako.quiz.ui.workbook.WorkbookListScreen

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
    const val WORKBOOK_DETAIL = "workbooks/{workbookId}"

    fun workbookDetail(id: Long) = "workbooks/$id"
}

@androidx.compose.runtime.Composable
private fun RikakoApp() {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = Routes.WORKBOOK_LIST) {
        composable(Routes.WORKBOOK_LIST) {
            WorkbookListScreen(
                onWorkbookClick = { id -> navController.navigate(Routes.workbookDetail(id)) },
            )
        }
        composable(
            route = Routes.WORKBOOK_DETAIL,
            arguments = listOf(navArgument("workbookId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val workbookId = backStackEntry.arguments?.getLong("workbookId") ?: return@composable
            WorkbookDetailScreen(workbookId = workbookId, onBack = navController::popBackStack)
        }
    }
}
