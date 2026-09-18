package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

internal val groupedBackground = Color(0xFFF2F2F7)
internal val managementSecondary = Color(0xFF6E7076)
internal val managementDivider = Color(0xFFE7E8E5)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ManagementTopBar(title: String, onBack: (() -> Unit)? = null) {
    TopAppBar(
        title = { Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold) },
        navigationIcon = {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = groupedBackground),
    )
}

@Composable
internal fun ManagementCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(
        modifier = modifier,
        color = Color.White,
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)),
    ) { content() }
}

@Composable
internal fun ManagementSectionTitle(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
    )
}

@Composable
internal fun ManagementIcon(icon: ImageVector, tint: Color) {
    Box(
        modifier = Modifier.size(32.dp).clip(CircleShape).background(tint.copy(alpha = 0.10f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(19.dp))
    }
}

@Composable
internal fun ManagementRow(
    title: String,
    icon: ImageVector,
    tint: Color,
    onClick: (() -> Unit)? = null,
    trailing: String? = null,
    subtitle: String? = null,
    badge: String? = null,
) {
    val rowModifier = if (onClick == null) Modifier else Modifier.clickable(onClick = onClick)
    Row(
        modifier = Modifier.fillMaxWidth().then(rowModifier).padding(horizontal = 16.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ManagementIcon(icon, tint)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = managementSecondary)
        }
        if (badge != null) {
            Text(
                badge,
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.clip(CircleShape).background(Color(0xFFEF8A24))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
        Text(
            trailing ?: if (onClick != null) "›" else "",
            color = managementSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
internal fun ManagementDivider() {
    HorizontalDivider(modifier = Modifier.padding(start = 62.dp), color = managementDivider)
}
