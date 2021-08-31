package com.marutifh.msalIntune;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.util.Base64;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.kpisoft.skylark.R;
import com.microsoft.identity.client.AuthenticationCallback; // Imports MSAL auth methods
import com.microsoft.identity.client.*;
import com.microsoft.identity.client.exception.*;

/**
 * This class echoes a string called from JavaScript.
 */
public class MSALIntune extends CordovaPlugin {
    private String keyHash;
    private static final String TAG = "MSALIntune";
    private final static String[] SCOPES = { "user.read" };
    private Activity activity;
    private Context context;
    private CallbackContext callbackContext;
    private CallbackContext loggerCallbackContext;
    private PluginResult loggerPluginResult;
    private ISingleAccountPublicClientApplication mSingleAccountApp;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        activity = cordova.getActivity();
        context = webView.getContext();

        // clientId = this.preferences.getString("clientId", "");
        // tenantId = this.preferences.getString("tenantId", "common");
         keyHash = this.preferences.getString("pathKeyHash", "");
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        this.callbackContext = callbackContext;
        try {
            if (action.equals("coolMethod")) {
                String message = args.getString(0);
                this.coolMethod(message);
            }
            if (action.equals("initMSALIntune")) {
                String instance = args.getString(0);
                this.initMSALIntune(new JSONObject(args.getString(0)));
            }
            if (action.equals("signOut")) {
                this.signOut();
            }
            if (action.equals("signInInteractive")) {
                this.signInInteractive();
            }
            if (action.equals("signIn")) {
                this.signIn();
            }
            if (action.equals("silentSignIn")) {
                this.silentSignIn();
            }
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
        return true;
    }

    private File createConfigFile(String data) {
        File config = new File(this.context.getFilesDir() + "/auth_config.json");
        try {
            FileWriter writer = new FileWriter(config, false);
            writer.write(data);
            writer.flush();
            writer.close();
            return config;
        } catch (IOException e) {
            callbackContext.error("createConfigFile:: Exception." + e.getMessage());
        }
        return config;
    }

    private void getHash(){
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(
                    "com.kpisoft.skylark",
                    PackageManager.GET_SIGNATURES
            );
            for (Signature signature : info.signatures) {
                MessageDigest md;
                md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                String something = new String(Base64.encode(md.digest(), 0));
                //String something = new String(Base64.encodeBytes(md.digest()));
                Log.e("KeyHash", something);
            }
        } catch (PackageManager.NameNotFoundException e1) {
            Log.e("name not found", e1.toString());
        } catch (NoSuchAlgorithmException e) {
            Log.e("no such an algorithm", e.toString());
        } catch (Exception e) {
            Log.e("exception", e.toString());
        }
    }

    private void getKeyHashFriendly(){
        String keyHashUrlFriendly = "";
        try {
            keyHashUrlFriendly = URLEncoder.encode(this.keyHash, "UTF-8");
            Log.e("Key Hash", keyHashUrlFriendly);
        } catch(UnsupportedEncodingException e) {
            this.callbackContext.error(e.getMessage());
        }
    }

    private void initMSALIntune(JSONObject options) {
        this.getKeyHashFriendly();
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                try {
                    File config = createConfigFile(options.toString().replaceAll("\\\\", ""));
                    mSingleAccountApp = PublicClientApplication.createSingleAccountPublicClientApplication(context,
                            config);
//                    R.raw.auth
                   config.delete();
                    MSALIntune.this.callbackContext.success();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                    MSALIntune.this.callbackContext.error("Interrupted Exception." + e.getMessage());
                } catch (MsalException e) {
                    e.printStackTrace();
                    MSALIntune.this.callbackContext.error("MsalException. " + e.getMessage());
                }
            }
        });
    }

    public void signOut() {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                if (mSingleAccountApp == null){
                    return;
                }
                mSingleAccountApp.signOut(new ISingleAccountPublicClientApplication.SignOutCallback() {
                    @Override
                    public void onSignOut() {
                        MSALIntune.this.callbackContext.success();
                    }
                    @Override
                    public void onError(@NonNull MsalException exception){
                        MSALIntune.this.callbackContext.error(exception.getMessage());
                    }
                });
            }
        });
    }

    public void signInInteractive() {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                if (mSingleAccountApp == null) {
                    return;
                }
                mSingleAccountApp.acquireToken(activity, SCOPES, getAuthInteractiveCallback());
            }
        });
    }

    private void silentSignIn(){
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                if (mSingleAccountApp == null) {
                    return;
                }
                String authority = mSingleAccountApp.getConfiguration().getDefaultAuthority().getAuthorityURL().toString();
                mSingleAccountApp.acquireTokenSilentAsync(SCOPES, authority, getAuthSilentCallback());
            }
        });
    }

    private void signIn(){
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                if (mSingleAccountApp == null) {
                    return;
                }
                mSingleAccountApp.signIn(activity, null, SCOPES, getAuthInteractiveCallback());
            }
        });
    }

    private JSONObject getAuthResult(IAuthenticationResult result) {
        JSONObject resultObj = new JSONObject();
        try {
            resultObj.put("token", result.getAccessToken());
            resultObj.put("account", getAccountObject(result.getAccount()));
        } catch (JSONException e) {
            MSALIntune.this.callbackContext.error(e.getMessage());
        }
        return resultObj;
    }

    private JSONObject getAccountObject(IAccount account) {
        JSONObject acct = new JSONObject();
        try {
            acct.put("id", account.getId());
            acct.put("username", account.getUsername());
            acct.put("claims", processClaims(account.getClaims()));
        } catch (JSONException e) {
            MSALIntune.this.callbackContext.error(e.getMessage());
        }
        return acct;
    }

    private JSONArray processClaims(Map<String, ?> claims) {
        JSONArray claimsArr = new JSONArray();
        for (Map.Entry<String, ?> claim : claims.entrySet()) {
            try {
                JSONObject claimObj = new JSONObject();
                claimObj.put("key", claim.getKey());
                claimObj.put("value", claim.getValue());
                claimsArr.put(claimObj);
            } catch (JSONException e) {
                MSALIntune.this.callbackContext.error(e.getMessage());
            }
        }
        return claimsArr;
    }

    private SilentAuthenticationCallback getAuthSilentCallback() {
        return new SilentAuthenticationCallback() {
            @Override
            public void onSuccess(IAuthenticationResult authenticationResult) {
                Log.d(TAG, "Successfully authenticated");
//                callGraphAPI(authenticationResult);
                MSALIntune.this.callbackContext.success(getAuthResult(authenticationResult));
            }
            @Override
            public void onError(MsalException exception) {
                Log.d(TAG, "Authentication failed: " + exception.toString());
//                displayError(exception);
                MSALIntune.this.callbackContext.error(exception.getMessage());
            }
        };
    }

    private AuthenticationCallback getAuthInteractiveCallback() {
        return new AuthenticationCallback() {
            @Override
            public void onSuccess(IAuthenticationResult authenticationResult) {
                /* Successfully got a token, use it to call a protected resource - MSGraph */
                Log.d(TAG, "Successfully authenticated");
                /* Update UI */
//                updateUI(authenticationResult.getAccount());
                /* call graph */
//                callGraphAPI(authenticationResult);
                MSALIntune.this.callbackContext.success(getAuthResult(authenticationResult));
            }

            @Override
            public void onError(MsalException exception) {
                /* Failed to acquireToken */
                Log.d(TAG, "Authentication failed: " + exception.toString());
//                displayError(exception);
                MSALIntune.this.callbackContext.error(exception.getMessage());
            }
            @Override
            public void onCancel() {
                /* User canceled the authentication */
                Log.d(TAG, "User cancelled login.");
                MSALIntune.this.callbackContext.error("Login cancelled.");
            }
        };
    }

    private void coolMethod(String message) {
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(
                    "com.kpisoft.skylark",
                    PackageManager.GET_SIGNATURES
            );
            for (Signature signature : info.signatures) {
                MessageDigest md;
                md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                String something = new String(Base64.encode(md.digest(), 0));
                //String something = new String(Base64.encodeBytes(md.digest()));
                Log.e("KeyHash::::::::", something);
                MSALIntune.this.callbackContext.success(something);
            }
        } catch (PackageManager.NameNotFoundException e1) {
            Log.e("name not found", e1.toString());
            MSALIntune.this.callbackContext.error("name not found:: " + e1.toString());
        } catch (NoSuchAlgorithmException e) {
            Log.e("no such an algorithm", e.toString());
            MSALIntune.this.callbackContext.error("no such an algorithm" + e.toString());
        } catch (Exception e) {
            Log.e("exception", e.toString());
            MSALIntune.this.callbackContext.error("exception:: " + e.toString());
        }
    }
}
