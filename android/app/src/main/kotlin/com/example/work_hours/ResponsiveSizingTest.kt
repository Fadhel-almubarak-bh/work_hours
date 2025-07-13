package com.example.work_hours

import android.util.Log

/**
 * Test class to verify responsive sizing logic
 */
class ResponsiveSizingTest {
    companion object {
        private const val TAG = "ResponsiveSizingTest"
        
        // Widget size thresholds (in dp)
        private const val SMALL_WIDGET_THRESHOLD = 100
        private const val MEDIUM_WIDGET_THRESHOLD = 150
        private const val LARGE_WIDGET_THRESHOLD = 200
        
        // Widget size data class
        data class WidgetSize(
            val width: Int,
            val height: Int,
            val isSmall: Boolean,
            val isMedium: Boolean,
            val isLarge: Boolean,
            val isExtraLarge: Boolean
        )
        
        // Responsive sizing data class
        data class ResponsiveSizing(
            val titleTextSize: Float,
            val subtitleTextSize: Float,
            val bodyTextSize: Float,
            val buttonTextSize: Float,
            val settingsButtonTextSize: Float,
            val gaugeMainTextSize: Float,
            val gaugeSubTextSize: Float,
            val calendarTextSize: Float,
            val buttonHeight: Int,
            val navButtonSize: Int,
            val settingsButtonSize: Int,
            val gaugeSize: Int
        )
        
        /**
         * Get the actual widget size and determine size category
         */
        fun getWidgetSize(minWidth: Int, minHeight: Int, density: Float): WidgetSize {
            // Convert from density-independent pixels to dp
            val widthDp = (minWidth / density).toInt()
            val heightDp = (minHeight / density).toInt()
            
            // Determine size category based on the smaller dimension
            val smallerDimension = minOf(widthDp, heightDp)
            
            val isSmall = smallerDimension < SMALL_WIDGET_THRESHOLD
            val isMedium = smallerDimension >= SMALL_WIDGET_THRESHOLD && smallerDimension < MEDIUM_WIDGET_THRESHOLD
            val isLarge = smallerDimension >= MEDIUM_WIDGET_THRESHOLD && smallerDimension < LARGE_WIDGET_THRESHOLD
            val isExtraLarge = smallerDimension >= LARGE_WIDGET_THRESHOLD
            
            Log.d(TAG, "[responsive] Widget size: ${widthDp}x${heightDp}dp, category: ${if (isSmall) "small" else if (isMedium) "medium" else if (isLarge) "large" else "extra-large"}")
            
            return WidgetSize(widthDp, heightDp, isSmall, isMedium, isLarge, isExtraLarge)
        }
        
        /**
         * Get responsive sizing configuration based on widget size
         */
        fun getResponsiveSizing(widgetSize: WidgetSize): ResponsiveSizing {
            return when {
                widgetSize.isSmall -> ResponsiveSizing(
                    titleTextSize = 12f,
                    subtitleTextSize = 11f,
                    bodyTextSize = 10f,
                    buttonTextSize = 11f,
                    settingsButtonTextSize = 9f,
                    gaugeMainTextSize = 12f,
                    gaugeSubTextSize = 9f,
                    calendarTextSize = 9f,
                    buttonHeight = 32,
                    navButtonSize = 28,
                    settingsButtonSize = 28,
                    gaugeSize = 120
                )
                widgetSize.isMedium -> ResponsiveSizing(
                    titleTextSize = 14f,
                    subtitleTextSize = 13f,
                    bodyTextSize = 12f,
                    buttonTextSize = 13f,
                    settingsButtonTextSize = 10f,
                    gaugeMainTextSize = 14f,
                    gaugeSubTextSize = 10f,
                    calendarTextSize = 10f,
                    buttonHeight = 36,
                    navButtonSize = 32,
                    settingsButtonSize = 32,
                    gaugeSize = 140
                )
                widgetSize.isLarge -> ResponsiveSizing(
                    titleTextSize = 16f,
                    subtitleTextSize = 15f,
                    bodyTextSize = 14f,
                    buttonTextSize = 15f,
                    settingsButtonTextSize = 12f,
                    gaugeMainTextSize = 16f,
                    gaugeSubTextSize = 12f,
                    calendarTextSize = 12f,
                    buttonHeight = 40,
                    navButtonSize = 36,
                    settingsButtonSize = 36,
                    gaugeSize = 160
                )
                else -> ResponsiveSizing( // Extra large
                    titleTextSize = 18f,
                    subtitleTextSize = 17f,
                    bodyTextSize = 16f,
                    buttonTextSize = 17f,
                    settingsButtonTextSize = 14f,
                    gaugeMainTextSize = 18f,
                    gaugeSubTextSize = 14f,
                    calendarTextSize = 14f,
                    buttonHeight = 44,
                    navButtonSize = 40,
                    settingsButtonSize = 40,
                    gaugeSize = 180
                )
            }
        }
        
        /**
         * Test the responsive sizing logic
         */
        fun testResponsiveSizing() {
            val density = 2.0f // Typical device density
            
            // Test small widget (80x80 dp)
            val smallWidget = getWidgetSize(160, 160, density) // 160px = 80dp at 2.0 density
            val smallSizing = getResponsiveSizing(smallWidget)
            Log.d(TAG, "Small widget test: title=${smallSizing.titleTextSize}sp, gauge=${smallSizing.gaugeSize}dp")
            
            // Test medium widget (120x120 dp)
            val mediumWidget = getWidgetSize(240, 240, density) // 240px = 120dp at 2.0 density
            val mediumSizing = getResponsiveSizing(mediumWidget)
            Log.d(TAG, "Medium widget test: title=${mediumSizing.titleTextSize}sp, gauge=${mediumSizing.gaugeSize}dp")
            
            // Test large widget (180x180 dp)
            val largeWidget = getWidgetSize(360, 360, density) // 360px = 180dp at 2.0 density
            val largeSizing = getResponsiveSizing(largeWidget)
            Log.d(TAG, "Large widget test: title=${largeSizing.titleTextSize}sp, gauge=${largeSizing.gaugeSize}dp")
            
            // Test extra large widget (250x250 dp)
            val extraLargeWidget = getWidgetSize(500, 500, density) // 500px = 250dp at 2.0 density
            val extraLargeSizing = getResponsiveSizing(extraLargeWidget)
            Log.d(TAG, "Extra large widget test: title=${extraLargeSizing.titleTextSize}sp, gauge=${extraLargeSizing.gaugeSize}dp")
        }
    }
}