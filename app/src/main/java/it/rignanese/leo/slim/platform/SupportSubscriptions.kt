package it.rignanese.leo.slim.platform

/**
 * Play Console subscription product IDs for the pay-what-you-want support slider.
 *
 * Each ID is a separate **annual** subscription with its own base plan/price.
 * Configure all four in Play Console under Monetize → Subscriptions before
 * shipping the `full` flavor.
 */
object SupportSubscriptions {
    const val TIER_1 = "support_yearly_1"
    const val TIER_2 = "support_yearly_2"
    const val TIER_3 = "support_yearly_3"
    const val TIER_4 = "support_yearly_4"

    val all = listOf(TIER_1, TIER_2, TIER_3, TIER_4)
}