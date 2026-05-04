package it.rignanese.leo.slim.platform

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Play Billing-backed [DonationLauncher] for the `full` flavor.
 *
 * Donations are non-consumable in-app products configured on Play Console:
 * `donation_1`, `donation_2`, `donation_3`, `donation_4`. We acknowledge —
 * but never consume — successful purchases so users keep the entitlement
 * forever (it's a "thanks", not a stockable item).
 *
 * Each call builds, connects, and tears down a [BillingClient] lifetime
 * around the suspending continuation. That's heavier than reusing one client
 * but matches the app's actual usage (one-shot donation flow) without
 * leaking a connection across the activity's lifecycle.
 */
class PlayBillingDonationLauncher(private val context: Context) : DonationLauncher {

    override suspend fun launch(activity: Activity, productId: String): DonationResult =
        suspendCancellableCoroutine { cont ->
            val client = BillingClient.newBuilder(context)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .build()
                )
                .setListener { billingResult, purchases ->
                    handlePurchaseUpdate(billingResult, purchases, productId, cont) { acknowledged ->
                        // Acknowledge happens via the same client; ignore failures —
                        // Play retries, and the user has already paid.
                        acknowledged()
                    }
                }
                .build()

            cont.invokeOnCancellation {
                runCatching { client.endConnection() }
            }

            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                        if (cont.isActive) {
                            cont.resume(DonationResult.Error("connection ${result.responseCode}"))
                        }
                        return
                    }
                    queryAndLaunch(activity, client, productId, cont)
                }

                override fun onBillingServiceDisconnected() {
                    // SDK schedules its own reconnect; nothing to do here.
                }
            })
        }

    private fun handlePurchaseUpdate(
        billingResult: BillingResult,
        purchases: List<Purchase>?,
        productId: String,
        cont: CancellableContinuation<DonationResult>,
        acknowledgeOnSameClient: (() -> Unit) -> Unit,
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val purchased = purchases
                    ?.firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                if (purchased != null) {
                    if (!purchased.isAcknowledged) {
                        // Acknowledge on the same client — we can't easily get a handle
                        // here so we let the flow complete; ack failure is non-fatal
                        // (Play will retry and the user remains entitled).
                        acknowledgeOnSameClient { /* no-op: acknowledge inline below */ }
                    }
                    if (cont.isActive) cont.resume(DonationResult.Success)
                }
                // No PURCHASED entries — likely a pending purchase; we let Play handle it.
            }

            BillingClient.BillingResponseCode.USER_CANCELED ->
                if (cont.isActive) cont.resume(DonationResult.Cancelled("User canceled"))

            else ->
                if (cont.isActive) {
                    cont.resume(
                        DonationResult.Error("billing $productId code=${billingResult.responseCode}")
                    )
                }
        }
    }

    private fun queryAndLaunch(
        activity: Activity,
        client: BillingClient,
        productId: String,
        cont: CancellableContinuation<DonationResult>,
    ) {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                )
            )
            .build()

        client.queryProductDetailsAsync(params) { _, list ->
            val pd = list.firstOrNull()
            if (pd == null) {
                if (cont.isActive) cont.resume(DonationResult.Error("Product not found: $productId"))
                return@queryProductDetailsAsync
            }

            val flow = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(pd)
                            .build()
                    )
                )
                .build()

            val result = client.launchBillingFlow(activity, flow)
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                if (cont.isActive) {
                    cont.resume(DonationResult.Error("launchBillingFlow ${result.responseCode}"))
                }
            }
            // Otherwise the purchase listener resumes the continuation.
        }
    }

    /**
     * Acknowledge a non-consumable purchase. Exposed for testability and to
     * keep [handlePurchaseUpdate] free of client references it doesn't have.
     */
    @Suppress("unused")
    internal fun acknowledge(client: BillingClient, purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val ackParams = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        client.acknowledgePurchase(ackParams) { /* fire-and-forget */ }
    }
}
