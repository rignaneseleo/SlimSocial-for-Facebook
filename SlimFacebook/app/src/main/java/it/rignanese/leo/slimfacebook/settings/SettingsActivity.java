package it.rignanese.leo.slimfacebook.settings;

import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceActivity;
import android.preference.PreferenceFragment;
import android.preference.PreferenceManager;
import android.support.annotation.NonNull;
import android.util.Log;
import android.view.View;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.Animation;
import android.view.animation.TranslateAnimation;
import android.widget.TextView;
import android.widget.Toast;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;

import java.util.ArrayList;
import java.util.List;

import it.rignanese.leo.slimfacebook.MainActivity;
import it.rignanese.leo.slimfacebook.R;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
public class SettingsActivity extends PreferenceActivity implements
        SharedPreferences.OnSharedPreferenceChangeListener {

    private static String appVersion;

    //using a PreferenceFragment along with the PreferenceActivity (see there
    // http://alvinalexander.com/android/android-tutorial-preferencescreen-preferenceactivity-preferencefragment )

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        //get the appVersion
        try {
            appVersion = appVersion();
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }


        //load the fragment
        getFragmentManager().beginTransaction().replace(android.R.id.content, new MyPreferenceFragment()).commit();

    }

    //read the appVersion
    private String appVersion() throws PackageManager.NameNotFoundException {
        PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
        return pInfo.versionName;
    }

    @Override
    public void onResume() {
        super.onResume();
        // register the listener
        PreferenceManager.getDefaultSharedPreferences(getApplicationContext()).registerOnSharedPreferenceChangeListener(this);
    }

    @Override
    public void onPause() {
        super.onPause();
        // unregister the listener
        PreferenceManager.getDefaultSharedPreferences(getApplicationContext()).unregisterOnSharedPreferenceChangeListener(this);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }


    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        switch (key) {
            case "pref_recentNewsFirst":
            case "pref_centerTextPosts":
            case "pref_fixedBar":
            case "pref_hideStories":
            case "pref_addSpaceBetweenPosts":
            case "pref_enableMessagesShortcut": {
                Toast.makeText(SettingsActivity.this, R.string.refreshToApply, Toast.LENGTH_SHORT).show();
                break;
            }
            case "pref_doNotDownloadImages":
            case "pref_allowGeolocation":
            case "pref_theme":
            case "pref_textSize": {
                restart();
                break;
            }
            case "pref_notifications": {
                Toast.makeText(SettingsActivity.this, R.string.noNotificationEnjoyLife, Toast.LENGTH_LONG).show();
                break;
            }
        }
    }

    private void restart() {
        // notify user
        Toast.makeText(SettingsActivity.this, R.string.applyingChanges, Toast.LENGTH_SHORT).show();

        // sending intent to onNewIntent() of MainActivity that restarts the app
        Intent intent = new Intent(getApplicationContext(), MainActivity.class);
        intent.putExtra("settingsChanged", true);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(intent);
    }


    //preference fragment
    public static class MyPreferenceFragment extends PreferenceFragment implements PurchasesUpdatedListener {
        private SharedPreferences savedPreferences;//contains all the values of saved preferences

        //donations
        private BillingClient billingClient;
        private SkuDetails donation1 = null;
        private SkuDetails donation2 = null;
        private SkuDetails donation3 = null;
        private SkuDetails donation4 = null;
        // donation dialog that will show on start donation process
        // and dismiss on end of donation process
        private AlertDialog donationDialog;

        @Override
        public void onCreate(final Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);
            savedPreferences = this.getActivity().getSharedPreferences("pref", Context.MODE_PRIVATE);

            addPreferencesFromResource(R.xml.settings);//load the layout

            setUpBillingClient();

            //set the appVersion
            Preference version = findPreference("pref_key_version");
            version.setSummary(appVersion);// set the current version
            findPreference("donate").setOnPreferenceClickListener(preference -> {
                setupDonation();
                return true;

            });
        }

        @Override
        public void onPurchasesUpdated(@NonNull BillingResult billingResult, List<Purchase> purchases) {
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
                for (Purchase purchase : purchases) {
                    //handleNonConcumablePurchase(purchase);
                    handlePurchases(purchase);
                }
            } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
                Toast.makeText(getActivity(), "Canceled!", Toast.LENGTH_SHORT).show();
                // Handle an error caused by a user cancelling the purchase flow.
            } else {
                Toast.makeText(getActivity(), getString(R.string.descriptionNoConnection), Toast.LENGTH_SHORT).show();
                // Handle any other error codes.
            }

        }

        private void setUpBillingClient() {
            billingClient = BillingClient.newBuilder(getActivity())
                    .setListener(this)
                    .enablePendingPurchases()
                    .build();
            startConnection();
        }

        private void startConnection() {
            billingClient.startConnection(new BillingClientStateListener() {
                @Override
                public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
                    if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        Log.v("TAG_INAPP", "Setup Billing Done");
                        // The BillingClient is ready. You can query purchases here.
                        queryAvailableProducts();
                    }
                }

                @Override
                public void onBillingServiceDisconnected() {
                    Log.v("TAG_INAPP", "Billing client Disconnected");
                    // Try to restart the connection on the next request to
                    // Google Play by calling the startConnection() method.
                }
            });
        }

        private void queryAvailableProducts() {
            List<String> skuList = new ArrayList<>();
            skuList.add("donation_1");
            skuList.add("donation_2");
            skuList.add("donation_3");
            skuList.add("donation_4");
            SkuDetailsParams.Builder builder = SkuDetailsParams.newBuilder();
            builder.setSkusList(skuList).setType(BillingClient.SkuType.INAPP);
            billingClient.querySkuDetailsAsync(builder.build(), (billingResult, skuDetailsList) -> {
                // Process the result.
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && skuDetailsList != null) {
                    for (SkuDetails skuDetails : skuDetailsList) {
                        if (skuDetails.getSku().equals("donation_1")) {
                            donation1 = skuDetails;

                        } else if (skuDetails.getSku().equals("donation_2")) {
                            donation2 = skuDetails;

                        } else if (skuDetails.getSku().equals("donation_3")) {
                            donation3 = skuDetails;

                        } else if (skuDetails.getSku().equals("donation_4")) {
                            donation4 = skuDetails;

                        }
                    }
                }
            });
        }

        private void handlePurchases(@NonNull Purchase purchase) {
            ConsumeParams consumeParams = ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build();
            billingClient.consumeAsync(consumeParams, (billingResult, purchaseToken) -> {
                if (donationDialog != null && donationDialog.isShowing()) {
                    donationDialog.dismiss();
                }
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    Toast.makeText(getActivity(), getString(R.string.thanks) + " :)", Toast.LENGTH_SHORT).show();
                    savedPreferences.edit().putBoolean("supporter", true).apply();
                    //savedPreferences.edit().putString("pref_theme", "donate_theme").apply();
                } else {
                    Log.w("TAG_INAPP", billingResult.getDebugMessage());
                }
            });
        }

        private void setupDonation() {
            if (donation1 == null) {
                Toast.makeText(getActivity(), getString(R.string.descriptionNoConnection), Toast.LENGTH_SHORT).show();
                return;
            }

            View donationView = getActivity().getLayoutInflater().inflate(R.layout.purchase_item, null, false);


            //View #2
            ((TextView) donationView.findViewById(R.id.tv_donation_1))
                    .setText(String.format("%s", donation1.getPrice()));
            ((TextView) donationView.findViewById(R.id.tv_donation_2))
                    .setText(String.format("%s", donation2.getPrice()));
            ((TextView) donationView.findViewById(R.id.tv_donation_3))
                    .setText(String.format("%s", donation3.getPrice()));
            ((TextView) donationView.findViewById(R.id.tv_donation_4))
                    .setText(String.format("%s", donation4.getPrice()));
            ((TextView) donationView.findViewById(R.id.tv_donation_0))
                    .setText(String.format("%s", donation1.getPrice().replaceAll("[0-9]", "0")));
            donationView.findViewById(R.id.donation_1).setOnClickListener(v -> startBillingFlow(donation1));
            donationView.findViewById(R.id.donation_2).setOnClickListener(v -> startBillingFlow(donation2));
            donationView.findViewById(R.id.donation_3).setOnClickListener(v -> startBillingFlow(donation3));
            donationView.findViewById(R.id.donation_4).setOnClickListener(v -> startBillingFlow(donation4));
            donationView.findViewById(R.id.donation_0).setOnClickListener(v -> {
                donationDialog.cancel();
            });



            donationDialog = new AlertDialog.Builder(getActivity())
                    .setTitle(getString(R.string.needsupport))
                    .setView(donationView)
                    .setCancelable(false)
                    .create();
            donationDialog.show();

            donationView.findViewById(R.id.root_mesg).setVisibility(View.GONE);
            View view = donationView.findViewById(R.id.root_donation);
            view.setVisibility(View.VISIBLE);
            view.startAnimation(inFromRightAnimation());
        }

        private Animation inFromRightAnimation() {

            Animation inFromRight = new TranslateAnimation(
                    Animation.RELATIVE_TO_PARENT, +1.0f,
                    Animation.RELATIVE_TO_PARENT, 0.0f,
                    Animation.RELATIVE_TO_PARENT, 0.0f,
                    Animation.RELATIVE_TO_PARENT, 0.0f);
            inFromRight.setDuration(300);
            inFromRight.setInterpolator(new AccelerateInterpolator());
            return inFromRight;
        }

        private void startBillingFlow(SkuDetails donation) {
            if (billingClient.isReady()) {
                BillingFlowParams flowParams = BillingFlowParams.newBuilder().setSkuDetails(donation).build();
                billingClient.launchBillingFlow(getActivity(), flowParams);
            }
        }
    }
}

