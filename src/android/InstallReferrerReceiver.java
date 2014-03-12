package com.distimo.sdk;

/**
 *  Copyright (c) 2012 Distimo. All rights reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Map;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;

public final class InstallReferrerReceiver extends BroadcastReceiver {

	private final static String TAG							= "InstallReferrerReceiver";
    private final static String PREFERENCES_FILE_NAME		= "pSBv5PukhoJz4TVu9Ga7";
    private static SharedPreferences installReferrerStorage	= null;
	
    @Override
    public void onReceive(Context context, Intent intent) {
    	if (Utils.DEBUG) { Log.i(TAG, "onReceive()"); }
    	
    	// Workaround for Android security issue: http://code.google.com/p/android/issues/detail?id=16006
        try {
            Bundle extras = intent.getExtras();
            if (extras != null) {
                extras.containsKey(null);
            }
        }
        catch (Exception e) { return; }
        
        // Return if this is not the right intent.
        if (!intent.getAction().equals("com.android.vending.INSTALL_REFERRER")) {
            return;
        }
 
        String referrer = intent.getStringExtra("referrer");
        if (referrer == null || referrer.length() == 0) {
            return;
        }
 
        if (!referrer.contains("=")) {
        	// Remove any URL encoding, there is no = character
            try {
                referrer = URLDecoder.decode(referrer, "UTF-8");
            } catch (UnsupportedEncodingException e) {
            	if (Utils.DEBUG) { e.printStackTrace(); }
            } catch (Exception e) {
            	if (Utils.DEBUG) { e.printStackTrace(); }
            }
        }
        
        //Store the params
        Map<String, String> referralParams = Utils.keyValueStringToMap(referrer);
        InstallReferrerReceiver.storeInstallReferrerParams(context, referralParams);
        
        //Try notifying the DistimoSDK
        try {
        	DistimoSDK.installReferrerUpdated(context);
        } catch (Exception e) {
        	if (Utils.DEBUG) { e.printStackTrace(); }
        }
    }
    
    /*
     * Stores the referral parameters in the app's sharedPreferences.
     */
    static void storeInstallReferrerParams(Context context, Map<String, String> params) {
    	if (Utils.DEBUG) { Log.i(TAG, "storeInstallReferrerParams()"); }
    	
        SharedPreferences storage = context.getSharedPreferences(InstallReferrerReceiver.PREFERENCES_FILE_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = storage.edit();
        
        //Clear the old params first
        editor.clear();
        
        //Store the new params
        for (String key : params.keySet()) {
            String value = params.get(key);
            if (value != null) {
                editor.putString(key, value);
            }
        }
        
        //Commit the changes
        editor.commit();
    }
 
    /*
     * Returns a map with the Market Referral parameters pulled from the sharedPreferences.
     */
    static Map<String, String> getInstallReferrerParams(Context context) {
    	if (Utils.DEBUG) { Log.i(TAG, "retrieveInstallReferrerParams()"); }
    	
        installReferrerStorage = context.getSharedPreferences(InstallReferrerReceiver.PREFERENCES_FILE_NAME, Context.MODE_PRIVATE);
        
        @SuppressWarnings("unchecked") //Only String values are put in the storage
		HashMap<String,String> params = (HashMap<String, String>) installReferrerStorage.getAll();
        
        return params;
    }
    
    static void clearInstallReferrerParams() {
    	if (installReferrerStorage != null) {
            installReferrerStorage.edit().clear().commit();
    	}
    }
}