package com.mdnahid.prayerlock

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class BlockerOverlayActivity : Activity() {

    companion object {
        const val EXTRA_BLOCKED_PACKAGE = "blocked_package"
    }

    private var unblockButton: Button? = null

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        applyWindowFlags()

        val blockedPackage = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: ""
        val appName = getAppName(blockedPackage)

        setContentView(buildLayout(appName))
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        // Intentionally blocked — user must confirm prayer before dismissing
    }

    // ── Window configuration ─────────────────────────────────────────────────

    private fun applyWindowFlags() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }

        window.statusBarColor = Color.parseColor("#0D1520")
        window.navigationBarColor = Color.parseColor("#0D1520")
    }

    // ── UI construction ──────────────────────────────────────────────────────

    private fun buildLayout(appName: String): View {
        val bg = Color.parseColor("#0D1520")
        val green = Color.parseColor("#10B981")
        val white = Color.WHITE
        val muted = Color.parseColor("#6B7E96")

        val scroll = ScrollView(this).apply {
            setBackgroundColor(bg)
            isFillViewport = true
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(32), dp(56), dp(32), dp(56))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT,
            )
        }

        // ── Lock icon ────────────────────────────────────────────────────────
        val iconFrame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(88), dp(88)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(24)
            }
            background = ovalDrawable("#1A3A2A")
        }
        val lockIcon = android.widget.ImageView(this).apply {
            setImageResource(R.drawable.ic_blocker_notify)
            setColorFilter(green)
            layoutParams = FrameLayout.LayoutParams(dp(44), dp(44), Gravity.CENTER)
        }
        iconFrame.addView(lockIcon)
        container.addView(iconFrame)

        // ── App name ─────────────────────────────────────────────────────────
        container.addView(
            TextView(this).apply {
                text = appName
                textSize = 24f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(white)
                gravity = Gravity.CENTER
                layoutParams = linearParams(bottomMargin = dp(8))
            },
        )

        // ── Subtitle ─────────────────────────────────────────────────────────
        container.addView(
            TextView(this).apply {
                text = "This app is blocked during prayer time"
                textSize = 14f
                setTextColor(muted)
                gravity = Gravity.CENTER
                layoutParams = linearParams(bottomMargin = dp(40))
            },
        )

        // ── Card ─────────────────────────────────────────────────────────────
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedDrawable("#152032", "#1E3A2A", dp(20).toFloat())
            setPadding(dp(24), dp(24), dp(24), dp(24))
            layoutParams = linearParams()
        }

        // Toggle row
        val toggleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = linearParams(bottomMargin = dp(20))
        }

        val checkbox = CheckBox(this).apply {
            isChecked = false
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { marginEnd = dp(12) }
            buttonTintList = android.content.res.ColorStateList.valueOf(green)
        }

        val toggleLabel = TextView(this).apply {
            text = "I have prayed — don't fake it,\nAllah is watching you \uD83E\uDD32"
            textSize = 14f
            setTextColor(white)
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f,
            )
        }

        toggleRow.addView(checkbox)
        toggleRow.addView(toggleLabel)
        card.addView(toggleRow)

        // Unblock button
        unblockButton = Button(this).apply {
            text = "Unblock"
            isEnabled = false
            alpha = 0.4f
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(white)
            background = roundedDrawable("#10B981", "#10B981", dp(12).toFloat())
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(52),
            )
            setOnClickListener { unblockAndFinish() }
        }
        card.addView(unblockButton)
        container.addView(card)

        checkbox.setOnCheckedChangeListener { _, isChecked ->
            unblockButton?.isEnabled = isChecked
            unblockButton?.alpha = if (isChecked) 1f else 0.4f
        }

        scroll.addView(container)
        return scroll
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    /**
     * User confirmed they prayed — clear `window_active` so the Accessibility
     * Service stops re-launching this overlay for the rest of the current
     * prayer window. The master switch (`auto_enabled`) stays on, so the
     * next adhan's start alarm will re-arm blocking.
     */
    private fun unblockAndFinish() {
        getSharedPreferences(
            PrayerLockAccessibilityService.PREFS_FILE,
            Context.MODE_PRIVATE,
        ).edit()
            .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, false)
            .apply()
        finish()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun getAppName(packageName: String): String = try {
        packageManager
            .getApplicationLabel(packageManager.getApplicationInfo(packageName, 0))
            .toString()
    } catch (_: Exception) {
        packageName
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun linearParams(bottomMargin: Int = 0): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            if (bottomMargin > 0) this.bottomMargin = bottomMargin
        }

    private fun ovalDrawable(colorHex: String): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor(colorHex))
        }

    private fun roundedDrawable(
        bgHex: String,
        strokeHex: String,
        radius: Float,
    ): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(Color.parseColor(bgHex))
            setStroke(dp(1), Color.parseColor(strokeHex))
        }
}
