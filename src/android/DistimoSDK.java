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
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.distimo.sdk.EventManager.Event;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager.NameNotFoundException;
import android.os.Handler;
import android.provider.Settings.Secure;
import android.util.Log;

public final class DistimoSDK {
	
	private final static String TAG								= "DistimoSDK";
	final static String VERSION									= "2.6";
    
	private final static String PREFERENCES_FILE_NAME			= "8KgNwA2MuiQEQmEYIiiW";
    private final static String PREFERENCES_UUID				= "FiiXtVPrKKw25oeAlQaS";
    private final static String PREFERENCES_HUID				= "9FVoDgY1vU7gVHge3vJj";
    private final static String PREFERENCES_FIRSTLAUNCH_PARAMS	= "v4b6nW85ZULPsEShuwdY";
    private final static String PREFERENCES_FIRSTLAUNCH_EMPTY	= "d9JG1L4PnM52E68ApSiK";
    private final static String PREFERENCES_USER_REGISTERED		= "E7EkjEbZANQq5x3BsJZc";
    private final static String PREFERENCES_USER_ID				= "mjaEKufRe6vNtt8PsciU";
    
	private final static long FIRSTLAUNCH_DELAY					= 30000; 
    
	private static Handler firstLaunchHandler;
	private static Runnable firstLaunchRunnable;
    private static SharedPreferences preferences;
	private static boolean started								= false;
	
	static String publicKey;
	static String privateKey;
	static String bundleID;
	static String uniqueUserID;
	static String uniqueHardwareID;
	static String appVersion;
	
	/**
	 * Private constructor to prevent instantiation
	 */
	private DistimoSDK() { }
	
	/**
	 * Retrieve the version of the SDK
	 *
	 * @return the version of the SDK
	 */
	public static String version() {
		return VERSION;
	}
	
	/**
	 * Start the SDK. Typically call this method from the onCreate(..) method of your main Activity
	 * 
	 * @param c The application context, can be the activity where you are calling this method from
	 * @param sdkKey Your SDK Key, go to https://analytics.distimo.com/settings/sdk to generate an SDK Key.
	 */
	public static void onCreate(Context c, String sdkKey) {
		if (sdkKey != null && !started) {
			if (Utils.DEBUG) { Log.i(TAG, "onCreate(" + sdkKey + ")"); }
			
			started = true;
			
			if (sdkKey.length() > 4) {
				//Get the public and private key from the SDK key
				publicKey = sdkKey.substring(0, 4);
				privateKey = sdkKey.substring(4);
				
				Context context = c.getApplicationContext();
				preferences = context.getSharedPreferences(PREFERENCES_FILE_NAME, Context.MODE_PRIVATE);

				//Get the application details
				bundleID = context.getPackageName();
				try {
					appVersion = context.getPackageManager().getPackageInfo(DistimoSDK.bundleID, 0).versionName;
				} catch (final NameNotFoundException nnfe) {
					if (Utils.DEBUG) { nnfe.printStackTrace(); }
					appVersion = "0";
				}
				
				//Generate IDs
				generateUniqueUserID();
				generateUniqueHardwareID(context);
				
				//Initialize the EventManager
				EventManager.initialize(context);
				
				//Set exception handler (will preserve the current exception handler)
				Thread.setDefaultUncaughtExceptionHandler(new DistimoExceptionHandler(context));
				
				//Check (delayed) if a FirstLaunch event needs to be sent
				checkFirstLaunchDelayed(context);
			}
		}
	}
	
	//-- USER VALUE --//
	
	/**
	 * Mark this user as newly registered
	 **/
	public static void onUserRegistered() {
		final boolean registered = preferences.getBoolean(PREFERENCES_USER_REGISTERED, false);
		
		if (!registered) {
			preferences.edit().putBoolean(PREFERENCES_USER_REGISTERED, true).commit();
			
			Event registeredEvent = new Event("UserRegistered", null, null);
			DistimoSDK.sendEvent(registeredEvent);
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "User already marked as registered"); }
		}
	}
	
	/**
	 * Log an in-app purchase that this user completed
	 * 
	 * @param productID The ID of the in-app product
	 * @param orderID The merchant order ID
	 */
	public static void onInAppPurchase(String productID, String orderID) {
		DistimoSDK.onInAppPurchase(productID, orderID, false);
	}
	
	/**
	 * Log in-app product that was refunded for this user
	 * 
	 * @param productID The ID of the in-app product
	 * @param orderID The merchant order ID
	 */
	public static void onInAppPurchaseRefunded(String productID, String orderID) {
		DistimoSDK.onInAppPurchase(productID, orderID, true);
	}
	
	private static void onInAppPurchase(String productID, String orderID, boolean refund) {
		Map<String, String> params = new HashMap<String, String>();
		params.put("productID", productID);
		params.put("orderID", orderID);
		params.put("quantity", (refund ? "-1" : "1"));
		
		Event purchaseEvent = new Event("InAppPurchase", params, null);
		DistimoSDK.sendEvent(purchaseEvent);
	}
	
	/**
	 * Log an external purchase that this user completed, e.g. consumer goods or a booking,
	 *  specified with an ISO 4217 international currency symbol
	 * 
	 * @param productID The productID of the external purchase
	 * @param currency The ISO 4217 currency code for the currency used for this purchase
	 * @param price The price of the product
	 * @param quantity Number of purchased products
	 */
	public static void onExternalPurchase(String productID, String currency, double price, int quantity) {
		Map<String, String> params = new HashMap<String, String>();
		params.put("productID", productID);
		params.put("currency", currency);
		params.put("price", Double.toString(price));
		params.put("quantity", Integer.toString(quantity));
		
		Event purchaseEvent = new Event("ExternalPurchase", params, null);
		DistimoSDK.sendEvent(purchaseEvent);
	}
	
	/**
	 * Log a banner click
	 *
	 * @param publisher The publisher of the banner (optional)
	 **/
	public static void onBannerClick(String publisher) {
		Map<String, String> params = new HashMap<String, String>();
		if (publisher != null) {
			params.put("publisher", publisher);
		}
		
		Event bannerEvent = new Event("BannerClick", params, null);
		DistimoSDK.sendEvent(bannerEvent);
	}
	
	//-- USER PROPERTIES --//
	
	/**
	 * Set a self-defined userID for this user. This userID is used to provide you with detailed
	 *  source information that this user originated from.
	 * 
	 * @param userID Your self-defined userID of this user
	 */
	public static void setUserID(String userID) {
		if (userID == null || userID.length() == 0) {
			//Don't send an empty userID
			return;
		}
		
		final String newUserID = userID;
		final String storedUserID = preferences.getString(PREFERENCES_USER_ID, null);
		
		if (storedUserID == null || !newUserID.equals(storedUserID)) {
			preferences.edit().putString(PREFERENCES_USER_ID, newUserID).commit();
			
			Map<String, String> params = new HashMap<String, String>();
			params.put("id", newUserID);
			
			Event userIdEvent = new Event("UserID", params, null);
			DistimoSDK.sendEvent(userIdEvent);
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "UserID already set as " + newUserID); }
		}
	}
	
	//-- APPLINK --//
	
	/**
	 * Redirects directly to the AppStore by routing through your AppLink. Use this for tracking
	 *  conversion from within your own apps, e.g. for upselling to your Pro apps.
	 *
	 * Note: The redirect will happen in the background, this can take a couple of seconds.
	 *
	 * @param applinkHandle The handle of the AppLink you want to open, e.g. @"A00"
	 * @param campaignHandle The handle of the campaign you want to use, e.g. @"a" (optional)
	 * @param activity The Activity object that should present the Intent for the application
	 **/
	public static void openAppLink(String applinkHandle, String campaignHandle, Activity activity) {
		AppLinkManager.openAppLink(applinkHandle, campaignHandle, activity);
	}
	
	//-- UNIQUE ID --//
	
	private static void generateUniqueUserID() {
		//Get from preferences file
		final String storedID = preferences.getString(PREFERENCES_UUID, null);
		
		if (storedID == null) {
			//Generate random
			String hexString = UUID.randomUUID().toString().replace("-", "").toLowerCase();
			uniqueUserID = Utils.base64Encode(hexString, true);

			//Store in preferences file
			preferences.edit().putString(PREFERENCES_UUID, uniqueUserID).commit();
		} else {
			uniqueUserID = storedID;
		}
	}
	
	private static void generateUniqueHardwareID(Context context) {
		String hexString = null;
		
		//Get the ANDROID_ID
		final String androidID = Secure.getString(context.getContentResolver(), Secure.ANDROID_ID);
		if (androidID != null) {
			if (!androidID.equals("9774d56d682e549c")) { //Android bug: same ANDROID_ID for some 2.2 devices (mainly DROID2)
				try {
					//Generate a unique ID based on the ANDROID_ID
					hexString = UUID.nameUUIDFromBytes(androidID.getBytes("UTF-8")).toString().replace("-", "").toLowerCase();
				} catch (final UnsupportedEncodingException uee) {
					if (Utils.DEBUG) { uee.printStackTrace(); }
				} catch (final AssertionError ae) {
					//Apparently this method can also throw an AssertionError
					if (Utils.DEBUG) { ae.printStackTrace(); }
				}
			}
		}
		
		//Get the hexString from the preferences
		if (hexString == null) {
			final String storedID = preferences.getString(PREFERENCES_HUID, null);
			if (storedID != null) {
				hexString = storedID;
			}
		}
		
		//Generate a random ID as a last resort
		if (hexString == null) {
			hexString = UUID.randomUUID().toString().replace("-", "").toLowerCase();
		}
		
		//Store in preferences file
		preferences.edit().putString(PREFERENCES_HUID, hexString).commit();
		
		//Base64 encode
		uniqueHardwareID = Utils.base64Encode(hexString, true);
	}
	
	//-- EVENT SENDING --//
	
	protected static void sendEvent(Event event) {
		if (Utils.DEBUG) { Log.i(TAG, "sendEvent()"); }
		
		EventManager.logEvent(event);
	}
	
	//-- FIRST LAUNCH --//
	
	static void installReferrerUpdated(Context context) {
		if (started) {
			DistimoSDK.checkFirstLaunch(context);
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "DistimoSDK not active, not sending INSTALL_REFERRER params"); }
		}
	}
	
	private static void checkFirstLaunchDelayed(final Context context) {
		//Check which first launch was already reported
		final boolean paramsReported = preferences.getBoolean(PREFERENCES_FIRSTLAUNCH_PARAMS, false);
		final boolean emptyReported = preferences.getBoolean(PREFERENCES_FIRSTLAUNCH_EMPTY, false);
		
		if (!paramsReported) {
			//Check if there are install referrer parameters to send
			Map<String, String> params = InstallReferrerReceiver.getInstallReferrerParams(context);
			
			if (!params.isEmpty()) {
				if (Utils.DEBUG) { Log.i(TAG, "Found INSTALL_REFERRER params, skipping delayed check"); }
				
				//Send immediately
				checkFirstLaunch(context);
			} else if (!emptyReported) {
				if (Utils.DEBUG) { Log.i(TAG, "FirstLaunch not yet reported, starting delayed check"); }
				
				firstLaunchRunnable = new Runnable() {
					public void run() {
						checkFirstLaunch(context);

						//Clear the Handler and the Runnable after checking
						firstLaunchHandler = null;
						firstLaunchRunnable = null;
					}
				};
				
				firstLaunchHandler = new Handler();
				firstLaunchHandler.postDelayed(firstLaunchRunnable, FIRSTLAUNCH_DELAY);
			} else {
				if (Utils.DEBUG) { Log.i(TAG, "Empty FirstLaunch already reported, not starting delayed check"); }
			}
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "FirstLaunch already reported, not starting delayed check"); }
		}
	}
	
	private static void checkFirstLaunch(Context context) {
		Event installEvent = null;
		Map<String, String> params = null;
		
		//Check which first launch was already reported
		final boolean paramsReported = preferences.getBoolean(PREFERENCES_FIRSTLAUNCH_PARAMS, false);
		final boolean emptyReported = preferences.getBoolean(PREFERENCES_FIRSTLAUNCH_EMPTY, false);
		
		if (!paramsReported) {
			//Check if there are install referrer parameters to send
			params = InstallReferrerReceiver.getInstallReferrerParams(context);
			
			if (!params.isEmpty()) {
				if (Utils.DEBUG) { Log.i(TAG, "Found INSTALL_REFERRER params"); }

				//Send the parameters (not necessarily our parameters)
				installEvent = new Event("FirstLaunch", params, null);
			} else if (!emptyReported) {
				if (Utils.DEBUG) { Log.i(TAG, "Reporting organic FirstLaunch"); }

				//Send an empty FirstLaunch event
				installEvent = new Event("FirstLaunch", null, null);
			} else {
				if (Utils.DEBUG) { Log.i(TAG, "Organic FirstLaunch already reported"); }
			}
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "FirstLaunch with INSTALL_REFERRER already reported"); }
		}

		if (installEvent != null) {
			//Send the event
			DistimoSDK.sendEvent(installEvent);
			
			//Set as sent
			DistimoSDK.setFirstLaunchSent(params.isEmpty());
			
			//Stop the delayed check
			if (firstLaunchHandler != null && firstLaunchRunnable != null) {
				firstLaunchHandler.removeCallbacks(firstLaunchRunnable);
			}
		}
	}
	
	private static void setFirstLaunchSent(boolean isEmpty) {
		if (Utils.DEBUG) { Log.i(TAG, "setFirstLaunchSent(" + (isEmpty ? "empty" : "with_params") + ")"); }
		
		//Don't clear the INSTALL_REFERRER
		//InstallReferrerReceiver.clearInstallReferrerParams();
		
		if (isEmpty) {
			preferences.edit().putBoolean(PREFERENCES_FIRSTLAUNCH_EMPTY, true).commit();
		} else {
			preferences.edit().putBoolean(PREFERENCES_FIRSTLAUNCH_PARAMS, true).commit();
		}
	}
}
