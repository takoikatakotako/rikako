package org.rikako.quiz.ui.record

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import org.rikako.quiz.data.model.UserSummary

private val dayLabels = listOf("月", "火", "水", "木", "金", "土", "日")

@Composable
internal fun StreakCard(summary: UserSummary) {
    val dates = remember(summary.studyDates) { summary.studyDates.toSet() }
    val week = remember { studyWeek() }
    val streak = remember(dates) { studyStreak(dates) }
    val weeklyCount = week.count { it.toString() in dates }
    var selectedDay by remember { mutableStateOf<LocalDate?>(null) }

    selectedDay?.let { day ->
        AlertDialog(
            onDismissRequest = { selectedDay = null },
            title = { Text("${day.monthValue}月${day.dayOfMonth}日") },
            text = { Text(if (day.toString() in dates) "学習しました ✓" else "学習していません") },
            confirmButton = { TextButton(onClick = { selectedDay = null }) { Text("閉じる") } },
        )
    }

    Card(
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Text("連続学習日数", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("今週の学習: ${weeklyCount}日", style = MaterialTheme.typography.bodySmall)
                }
                Text("${streak}日", style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                week.forEachIndexed { index, day ->
                    val studied = day.toString() in dates
                    Column(
                        modifier = Modifier.weight(1f).clickable { selectedDay = day },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(dayLabels[index], style = MaterialTheme.typography.labelSmall)
                        Box(
                            modifier = Modifier.size(24.dp)
                                .background(
                                    if (studied) MaterialTheme.colorScheme.primary else Color.Transparent,
                                    CircleShape,
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                if (studied) "✓" else "○",
                                color = if (studied) Color.White else MaterialTheme.colorScheme.primary,
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun StudyHistoryHeatmap(summary: UserSummary) {
    val dates = remember(summary.studyDates) { summary.studyDates.toSet() }
    val weeks = remember { studyHeatmap() }
    val scroll = rememberScrollState()
    LaunchedEffect(weeks) {
        snapshotFlow { scroll.maxValue }.first { it > 0 }
        scroll.scrollTo(scroll.maxValue)
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("今までの学習記録", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(modifier = Modifier.fillMaxWidth().horizontalScroll(scroll), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Spacer(Modifier.height(16.dp))
                        dayLabels.forEachIndexed { index, label ->
                            Text(if (index % 2 == 0) label else "", modifier = Modifier.size(width = 18.dp, height = 11.dp), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                    weeks.forEach { week ->
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            val monthStart = week.firstOrNull { it?.dayOfMonth == 1 }
                            Text(
                                monthStart?.let { "${it.monthValue}月" } ?: "",
                                modifier = Modifier.size(width = 11.dp, height = 16.dp),
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                                softWrap = false,
                            )
                            week.forEach { day ->
                                Box(
                                    modifier = Modifier.size(11.dp).background(
                                        when {
                                            day == null -> Color.Transparent
                                            day.toString() in dates -> MaterialTheme.colorScheme.primary.copy(alpha = 0.8f)
                                            else -> MaterialTheme.colorScheme.surfaceVariant
                                        },
                                        RoundedCornerShape(2.dp),
                                    ),
                                )
                            }
                        }
                    }
                }
                Text("■ 学習した日", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}
