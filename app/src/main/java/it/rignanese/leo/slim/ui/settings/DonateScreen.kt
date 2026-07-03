package it.rignanese.leo.slim.ui.settings

import android.app.Activity
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.platform.DonationLauncher
import it.rignanese.leo.slim.platform.DonationResult
import it.rignanese.leo.slim.platform.ProEntitlement
import it.rignanese.leo.slim.platform.SupportSubscriptions
import kotlinx.coroutines.launch

/**
 * Annual support tiers configured on Play Console as subscriptions.
 * The slider snaps to these discrete products — Play Billing cannot charge
 * arbitrary amounts, so the Yuka-style UX maps mood + copy onto fixed SKUs.
 */
internal data class DonationTier(
    val productId: String,
    val labelRes: Int,
    val mood: DonateMascotMood,
)

internal enum class DonateMascotMood {
    Sad,
    Neutral,
    Happy,
    Excited,
}

internal val DonationTiers = listOf(
    DonationTier(SupportSubscriptions.TIER_1, R.string.donate_tier_modest, DonateMascotMood.Sad),
    DonationTier(SupportSubscriptions.TIER_2, R.string.donate_tier_fair, DonateMascotMood.Neutral),
    DonationTier(SupportSubscriptions.TIER_3, R.string.donate_tier_generous, DonateMascotMood.Happy),
    DonationTier(SupportSubscriptions.TIER_4, R.string.donate_tier_hero, DonateMascotMood.Excited),
)

/** Default tier index — anchors the slider toward the middle, like Yuka's $15 default. */
private const val DefaultTierIndex = 2

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DonateScreen(
    donationLauncher: DonationLauncher,
    proEntitlement: ProEntitlement,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }

    var sliderValue by remember { mutableFloatStateOf(DefaultTierIndex.toFloat()) }
    var isLoading by remember { mutableStateOf(false) }

    val tierIndex = sliderValue.toInt().coerceIn(0, DonationTiers.lastIndex)
    val tier = DonationTiers[tierIndex]

    val moodMessage = when (tier.mood) {
        DonateMascotMood.Sad -> stringResource(R.string.donate_mood_low)
        DonateMascotMood.Neutral -> stringResource(R.string.donate_mood_neutral)
        DonateMascotMood.Happy -> stringResource(R.string.donate_mood_high)
        DonateMascotMood.Excited -> stringResource(R.string.donate_mood_excited)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.donate)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                        )
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            DonateMascot(
                mood = tier.mood,
                modifier = Modifier.size(140.dp),
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = stringResource(R.string.donate_support_headline),
                style = MaterialTheme.typography.headlineSmall,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.donate_support_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = stringResource(tier.labelRes),
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = moodMessage,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Slider(
                value = sliderValue,
                onValueChange = { sliderValue = it },
                valueRange = 0f..DonationTiers.lastIndex.toFloat(),
                steps = DonationTiers.size - 2,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp),
            )

            Text(
                text = if (BuildConfig.IS_FULL_FLAVOR) {
                    stringResource(R.string.donate_subscription_note)
                } else {
                    stringResource(R.string.donate_fdroid_note)
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = {
                    if (activity == null || isLoading) return@Button
                    scope.launch {
                        isLoading = true
                        val result = donationLauncher.launch(activity, tier.productId)
                        if (result is DonationResult.Success) {
                            // Unlock gated features immediately (spec §3.2). Fail-soft:
                            // the background verification retries on next app start.
                            runCatching { proEntitlement.refresh() }
                        }
                        isLoading = false
                        val message = when (result) {
                            DonationResult.Success ->
                                context.getString(R.string.thankyou)
                            DonationResult.External ->
                                context.getString(R.string.donate_external_opened)
                            is DonationResult.Cancelled -> null
                            is DonationResult.Error ->
                                context.getString(R.string.error_trylater)
                        }
                        message?.let { snackbar.showSnackbar(it) }
                    }
                },
                enabled = !isLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text(stringResource(R.string.donate_cta))
                }
            }
        }
    }
}

@Composable
private fun DonateMascot(
    mood: DonateMascotMood,
    modifier: Modifier = Modifier,
) {
    val bounce by animateFloatAsState(
        targetValue = when (mood) {
            DonateMascotMood.Sad -> 0.92f
            DonateMascotMood.Neutral -> 1f
            DonateMascotMood.Happy -> 1.06f
            DonateMascotMood.Excited -> 1.12f
        },
        animationSpec = spring(),
        label = "mascotBounce",
    )

    val primary = MaterialTheme.colorScheme.primary
    val onPrimary = MaterialTheme.colorScheme.onPrimary

    Canvas(modifier = modifier) {
        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = size.minDimension / 2f * bounce

        drawCircle(color = primary, radius = radius, center = center)

        val eyeOffsetX = radius * 0.28f
        val eyeOffsetY = -radius * 0.12f
        val eyeRadius = radius * 0.09f
        drawCircle(
            color = onPrimary,
            radius = eyeRadius,
            center = center + Offset(-eyeOffsetX, eyeOffsetY),
        )
        drawCircle(
            color = onPrimary,
            radius = eyeRadius,
            center = center + Offset(eyeOffsetX, eyeOffsetY),
        )

        val mouthY = radius * 0.22f
        val mouthWidth = radius * 0.55f
        val mouthColor = onPrimary.copy(alpha = 0.9f)
        when (mood) {
            DonateMascotMood.Sad -> {
                drawArc(
                    color = mouthColor,
                    startAngle = 200f,
                    sweepAngle = 140f,
                    useCenter = false,
                    topLeft = Offset(center.x - mouthWidth / 2f, center.y + mouthY * 0.4f),
                    size = Size(mouthWidth, mouthWidth * 0.55f),
                    style = Stroke(width = radius * 0.07f, cap = StrokeCap.Round),
                )
            }
            DonateMascotMood.Neutral -> {
                drawLine(
                    color = mouthColor,
                    start = center + Offset(-mouthWidth / 2f, mouthY),
                    end = center + Offset(mouthWidth / 2f, mouthY),
                    strokeWidth = radius * 0.07f,
                    cap = StrokeCap.Round,
                )
            }
            DonateMascotMood.Happy -> {
                drawArc(
                    color = mouthColor,
                    startAngle = 20f,
                    sweepAngle = 140f,
                    useCenter = false,
                    topLeft = Offset(center.x - mouthWidth / 2f, center.y + mouthY * 0.1f),
                    size = Size(mouthWidth, mouthWidth * 0.55f),
                    style = Stroke(width = radius * 0.07f, cap = StrokeCap.Round),
                )
            }
            DonateMascotMood.Excited -> {
                drawArc(
                    color = mouthColor,
                    startAngle = 15f,
                    sweepAngle = 150f,
                    useCenter = false,
                    topLeft = Offset(center.x - mouthWidth / 2f, center.y),
                    size = Size(mouthWidth, mouthWidth * 0.7f),
                    style = Stroke(width = radius * 0.08f, cap = StrokeCap.Round),
                )
                val cheekRadius = radius * 0.12f
                val cheekColor = Color(0xFFFFB4C2)
                drawCircle(
                    color = cheekColor,
                    radius = cheekRadius,
                    center = center + Offset(-eyeOffsetX * 1.35f, mouthY * 0.55f),
                )
                drawCircle(
                    color = cheekColor,
                    radius = cheekRadius,
                    center = center + Offset(eyeOffsetX * 1.35f, mouthY * 0.55f),
                )
            }
        }
    }
}