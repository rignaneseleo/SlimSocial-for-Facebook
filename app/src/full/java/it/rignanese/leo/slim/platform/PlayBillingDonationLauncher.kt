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
 * Support tiers are **annual subscriptions** configured on Play Console:
 * [SupportSubscriptions.TIER_1] … [SupportSubscriptions.TIER_4]. Each tier is a
 * separate subscription product with one base plan; the donate slider picks
 * which plan to offer. Purchases are acknowledged but never consumed.
 */
class PlayBillingDonationLauncher(private val context: Context) : DonationLauncher {

    override suspend fun launch(activity: Activity, productId: String): DonationResult =
        suspendCancellableCoroutine { cont ->
            lateinit var client: BillingClient
            client = BillingClient.newBuilder(context)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .enablePrepaidPlans()
                        .build()
                )
                .setListener { billingResult, purchases ->
                    handlePurchaseUpdate(billingResult, purchases, productId, cont, client)
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
        client: BillingClient,
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val purchased = purchases?.firstOrNull { purchase ->
                    purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                        purchase.products.contains(productId)
                }
                if (purchased != null) {
                    if (!purchased.isAcknowledged) {
                        acknowledge(client, purchased)
                    }
                    if (cont.isActive) cont.resume(DonationResult.Success)
                }
                // No PURCHASED entries — likely a pending purchase; Play handles it.
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
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                )
            )
            .build()

        client.queryProductDetailsAsync(params) { _, list ->
            val productDetails = list.firstOrNull()
            if (productDetails == null) {
                if (cont.isActive) {
                    cont.resume(DonationResult.Error("Subscription not found: $productId"))
                }
                return@queryProductDetailsAsync
            }

            val offerToken = productDetails.subscriptionOfferDetails
                ?.firstOrNull()
                ?.offerToken
            if (offerToken == null) {
                if (cont.isActive) {
                    cont.resume(DonationResult.Error("No offer for subscription: $productId"))
                }
                return@queryProductDetailsAsync
            }

            val flow = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(productDetails)
                            .setOfferToken(offerToken)
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

    internal fun acknowledge(client: BillingClient, purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val ackParams = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        client.acknowledgePurchase(ackParams) { /* fire-and-forget */ }
    }
}