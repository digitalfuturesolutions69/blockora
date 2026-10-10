package com.digitalfuturesolutions.blockora.platform;

import androidx.annotation.NonNull;
import com.android.billingclient.api.*;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/** Test-only feasibility bridge. No gameplay reference and no premium grant. */
public final class BlockoraPlatform extends GodotPlugin {
    private static final String PRODUCT = "remove_ads_lifetime";
    private static final String TEST_REWARDED = "ca-app-pub-3940256099942544/5224354917";
    private BillingClient billing;
    private boolean connecting;
    private final Set<String> purchasedTokens = java.util.concurrent.ConcurrentHashMap.newKeySet();

    public BlockoraPlatform(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "BlockoraPlatform"; }
    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Collections.singletonList(
            new SignalInfo("platform_status", String.class, String.class)));
    }
    private void status(String service, String state) { emitSignal("platform_status", service, state); }

    @UsedByGodot public void load_test_rewarded_ad() {
        runOnHostThread(() -> {
            if (getActivity() == null) { status("ads", "activity_unavailable"); return; }
            // Explicit opt-in method only; no show/reward or production ad unit.
            MobileAds.initialize(getActivity(), initialization -> runOnHostThread(() ->
                RewardedAd.load(getActivity(), TEST_REWARDED, new AdRequest.Builder().build(),
                    new RewardedAdLoadCallback() {
                        @Override public void onAdLoaded(@NonNull RewardedAd ad) {
                            status("ads", "test_ad_loaded");
                        }
                        @Override public void onAdFailedToLoad(@NonNull LoadAdError error) {
                            status("ads", "load_failed_" + error.getCode());
                        }
                    })));
        });
    }

    @UsedByGodot public void connect_billing() {
        runOnHostThread(() -> {
            if (getActivity() == null) { status("billing", "activity_unavailable"); return; }
            if (billing != null && billing.isReady()) { status("billing", "ready"); return; }
            if (connecting) return;
            if (billing == null) {
                billing = BillingClient.newBuilder(getActivity())
                    .setListener((result, purchases) -> {
                        // Tokens/identifiers never go to logs, analytics, or GDScript.
                        purchasedTokens.clear();
                        if (result.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
                            purchases.forEach(this::observePurchase);
                        } else status("billing", "purchase_update_" + result.getResponseCode());
                    })
                    .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                    .build();
            }
            connecting = true;
            billing.startConnection(new BillingClientStateListener() {
                @Override public void onBillingSetupFinished(@NonNull BillingResult result) {
                    connecting = false;
                    status("billing", result.getResponseCode() == BillingClient.BillingResponseCode.OK
                        ? "ready" : "connection_failed_" + result.getResponseCode());
                }
                @Override public void onBillingServiceDisconnected() {
                    connecting = false;
                    purchasedTokens.clear();
                    status("billing", "disconnected");
                }
            });
        });
    }

    @UsedByGodot public void query_remove_ads_product() {
        runOnHostThread(() -> {
            if (billing == null || !billing.isReady()) { status("billing", "not_ready"); return; }
            QueryProductDetailsParams.Product product = QueryProductDetailsParams.Product.newBuilder()
                .setProductId(PRODUCT).setProductType(BillingClient.ProductType.INAPP).build();
            billing.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder()
                .setProductList(Collections.singletonList(product)).build(), (result, details) ->
                    status("billing", result.getResponseCode() == BillingClient.BillingResponseCode.OK
                        && !details.getProductDetailsList().isEmpty() ? "product_available" : "product_unavailable"));
        });
    }

    @UsedByGodot public void restore_purchases() {
        runOnHostThread(() -> {
            if (billing == null || !billing.isReady()) { status("billing", "not_ready"); return; }
            billing.queryPurchasesAsync(QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP).build(), (result, purchases) -> {
                    purchasedTokens.clear();
                    if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        purchases.forEach(this::observePurchase);
                        status("billing", "restore_query_completed");
                    } else status("billing", "restore_failed_" + result.getResponseCode());
                });
        });
    }
    private void observePurchase(Purchase purchase) {
        if (!purchase.getProducts().contains(PRODUCT)) return;
        if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) {
            status("billing", "pending_no_entitlement");
        } else if (purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED) {
            purchasedTokens.add(purchase.getPurchaseToken());
            status("billing", "purchased_requires_verification");
        }
    }
    // No public acknowledgement entry point: acknowledge only after owner-approved
    // purchase verification exists. Keep the SDK acknowledgement API compile-checked.
    private void acknowledgeVerifiedPurchase(String token) {
        if (billing == null || !billing.isReady() || !purchasedTokens.contains(token)) return;
        billing.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build(),
            result -> status("billing", "acknowledgement_" + result.getResponseCode()));
    }
    @Override public void onMainDestroy() {
        if (billing != null) billing.endConnection();
        connecting = false;
        purchasedTokens.clear();
        super.onMainDestroy();
    }
}
