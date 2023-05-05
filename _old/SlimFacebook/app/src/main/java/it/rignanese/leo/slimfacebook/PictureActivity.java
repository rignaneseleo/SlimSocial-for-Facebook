package it.rignanese.leo.slimfacebook;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.view.Menu;
import android.view.MenuItem;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.widget.Toast;

import java.io.File;
import java.util.Date;

import it.rignanese.leo.slimfacebook.utility.MyAdvancedWebView;


/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */

public class PictureActivity extends Activity implements MyAdvancedWebView.Listener {
    private MyAdvancedWebView webViewPicture;//the main webView where is shown facebook
    private SharedPreferences savedPreferences;//contains all the values of saved preferences
    private DownloadManager downloadManager;
    private long idDownloadedFile = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_picture);

        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this); // setup the sharedPreferences
        downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);

        BroadcastReceiver receiver = downloadCompletedReceiver;
        registerReceiver(receiver, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));

        SetupPictureWebView();

        String pictureUrl = getIntent().getStringExtra("URL");
        webViewPicture.loadUrl(pictureUrl);
    }

    BroadcastReceiver downloadCompletedReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(action)) {
                long downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, 0);
                DownloadManager.Query query = new DownloadManager.Query();

                query.setFilterById(idDownloadedFile);
                Cursor c = downloadManager.query(query);
                if (c.moveToFirst()) {
                    int columnIndex = c.getColumnIndex(DownloadManager.COLUMN_STATUS);
                    if (DownloadManager.STATUS_SUCCESSFUL == c.getInt(columnIndex)) {
                        //get the url
                        String pictureUri = c.getString(c.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI));

                        // Create the URI from the media
                        File media = new File(Uri.parse(pictureUri).getPath());
                        Uri uri = Uri.fromFile(media);

                        //to share
                        Intent shareIntent = new Intent(Intent.ACTION_SEND);
                        shareIntent.setType("image/jpeg");
                        shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
                        startActivity(Intent.createChooser(shareIntent, getString(R.string.share)));

                        //reset
                        idDownloadedFile = -1;
                    }
                }
            }
        }
    };

    private void DownloadPicture(String url, boolean share) {
        //check permission
        if (Build.VERSION.SDK_INT >= 23 && ContextCompat.checkSelfPermission(this,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_DENIED) {
            //ask permission
            Toast.makeText(getApplicationContext(), getString(R.string.acceptPermissionAndRetry),
                    Toast.LENGTH_LONG).show();
            int requestResult = 0;
            ActivityCompat.requestPermissions(this,
                    new String[]{android.Manifest.permission.WRITE_EXTERNAL_STORAGE}, requestResult
            );
        } else {
            //download photo
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setTitle("SlimSocial Download");

            request.allowScanningByMediaScanner();
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

            Date date = new Date();
            long timeMilli = date.getTime();
            String filename = "SlimSocial_" + timeMilli + ".jpg";
            if (savedPreferences.getBoolean("pref_useSlimSocialSubfolderToDownloadedFiles", false)) {
                filename = "SlimSocial/"+filename;
            }

            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_PICTURES, filename);

            if (share)
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_HIDDEN);

            // get download service and enqueue file
            long _idDownloadedFile = downloadManager.enqueue(request);

            if (share)
                idDownloadedFile = _idDownloadedFile;
            else
                Toast.makeText(getApplicationContext(), getString(R.string.downloadingPhoto),
                        Toast.LENGTH_LONG).show();
        }
    }

    //*********************** MENU ****************************
    //add my menu
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.picture_menu, menu);
        return true;
    }

    //handling the tap on the menu's items
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.share: {//scroll on the top of the page
                DownloadPicture(webViewPicture.getUrl(), true);
                break;
            }
            case R.id.download: {//scroll on the top of the page
                DownloadPicture(webViewPicture.getUrl(), false);
                break;
            }
            default:
                break;
        }

        return super.onOptionsItemSelected(item);
    }

    //*********************** WEBVIEW ****************************
    private void SetupPictureWebView() {
        webViewPicture = findViewById(R.id.webViewPicture);
        webViewPicture.setListener(this, this);

        //  webViewPicture.setDesktopMode(true);

        //webViewPicture.requestFocus(View.F);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);//remove the keyboard issue


        WebSettings settings = webViewPicture.getSettings();

        settings.setBuiltInZoomControls(true);
        settings.setUseWideViewPort(true);
        settings.setJavaScriptEnabled(true);
        settings.setLoadWithOverviewMode(true);
        settings.setDisplayZoomControls(false);
    }

    @Override
    public void onPageStarted(String url, Bitmap favicon) {
    }

    @Override
    public void onPageFinished(String url) {
    }

    @Override
    public void onPageError(int errorCode, String description, String failingUrl) {
    }

    @Override
    public void onDownloadRequested(String url, String suggestedFilename, String mimeType, long contentLength, String contentDisposition, String userAgent) {
    }

    @Override
    public void onExternalPageRequest(String url) {
    }

    @Override
    public boolean shouldLoadUrl(String url) {
        return true;
    }
}
