package it.rignanese.leo.slim.platform

import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Thin seam over the Play Billing "query current subscriptions" call so
 * [PlayBillingProEntitlement]'s mapping/cache logic is unit-testable with a
 * fake. Only the `full` flavor has an implementation talking to Play.
 */
interface BillingConnector {
    /**
     * Product ids of all subscriptions currently in the PURCHASED state for
     * this Google account, or a failure when Play is unreachable (offline,
     * no Play services, connection error).
     */
    suspend fun queryActiveSubscriptionProductIds(): Result<List<String>>
}

/**
 * Real Play Billing connector. One short-lived [BillingClient] per query —
 * the entitlement refreshes rarely (app start + after purchase), so holding
 * a persistent connection isn't worth the lifecycle complexity. Mirrors the
 * connection dance in [PlayBillingDonationLauncher].
 */
class PlayBillingConnector(private val context: Context) : BillingConnector {

    override suspend fun queryActiveSubscriptionProductIds(): Result<List<String>> =
        suspendCancellableCoroutine { cont ->
            lateinit var client: BillingClient
            client = BillingClient.newBuilder(context)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .enablePrepaidPlans()
                        .build()
                )
                // Purchase updates are handled by PlayBillingDonationLauncher;
                // this client only queries, but the SDK requires a listener.
                .setListener { _, _ -> }
                .build()

            cont.invokeOnCancellation {
                runCatching { client.endConnection() }
            }

            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                        if (cont.isActive) {
                            cont.resume(
                                Result.failure(IllegalStateException("connection ${result.responseCode}"))
                            )
                        }
                        return
                    }
                    val params = QueryPurchasesParams.newBuilder()
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                    client.queryPurchasesAsync(params) { queryResult, purchases ->
                        runCatching { client.endConnection() }
                        if (!cont.isActive) return@queryPurchasesAsync
                        if (queryResult.responseCode == BillingClient.BillingResponseCode.OK) {
                            val ids = purchases
                                .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                                .flatMap { it.products }
                            cont.resume(Result.success(ids))
                        } else {
                            cont.resume(
                                Result.failure(IllegalStateException("query ${queryResult.responseCode}"))
                            )
                        }
                    }
                }

                override fun onBillingServiceDisconnected() {
                    // SDK schedules its own reconnect; nothing to do here.
                }
            })
        }
}
