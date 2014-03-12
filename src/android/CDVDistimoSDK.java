package com.distimo.sdk.cordova;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

import com.distimo.sdk.DistimoSDK;

public class CDVDistimoSDK extends CordovaPlugin {

	@Override
	public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {
		try {
			if (action.equals("start")) {
				if (args.length() >= 1) {
					String sdkKey = args.getString(0);
					this.start(sdkKey, callbackContext);
					return true;
				}
			} else if (action.equals("version")) {
				this.version(callbackContext);
				return true;
			} else if (action.equals("logUserRegistered")) {
				this.logUserRegistered(callbackContext);
				return true;
			} else if (action.equals("logInAppPurchase")) {
				if (args.length() >= 2) {
					String productID = args.getString(0);
					String orderID = args.getString(1);
					this.logInAppPurchase(productID, orderID, callbackContext);
					return true;
				}
			} else if (action.equals("logInAppPurchaseRefunded")) {
				if (args.length() >= 2) {
					String productID = args.getString(0);
					String orderID = args.getString(1);
					this.logInAppPurchaseRefunded(productID, orderID, callbackContext);
					return true;
				}
			} else if (action.equals("logExternalPurchaseWithCurrency")) {
				if (args.length() >= 4) {
					String productID = args.getString(0);
					String currency = args.getString(1);
					double price = args.getDouble(2);
					int quantity = args.getInt(3);
					this.logExternalPurchaseWithCurrency(productID, currency, price, quantity, callbackContext);
					return true;
				}
			} else if (action.equals("logBannerClick")) {
				String publisher = (args.isNull(0) ? null : args.getString(0));
				this.logBannerClick(publisher, callbackContext);
				return true;
			} else if (action.equals("setUserID")) {
				String userID = (args.isNull(0) ? null : args.getString(0));
				this.setUserID(userID, callbackContext);
				return true;
			} else if (action.equals("openAppLink")) {
				if (args.length() >= 1) {
					String applinkHandle = args.getString(0);
					String campaignHandle = (args.isNull(1) ? null : args.getString(1));
					this.openAppLink(applinkHandle, campaignHandle, callbackContext);
					return true;
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
		
		return false;
	}
	
	private void start(String sdkKey, CallbackContext callbackContext) {
		if (sdkKey != null && sdkKey.length() > 0) {
			DistimoSDK.onCreate(cordova.getActivity(), sdkKey);
			callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
		} else {
			callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Please provide a valid SDK Key, you can create one at https://analytics.distimo.com/settings/sdk."));
		}
	}
	
	private void version(CallbackContext callbackContext) {
		String version = DistimoSDK.version();
		if (version != null && version.length() > 0) {
			callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
		} else {
			callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "No DistimoSDK version found."));
		}
	}
	
	private void logUserRegistered(CallbackContext callbackContext) {
		DistimoSDK.onUserRegistered();
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void logInAppPurchase(String productID, String orderID, CallbackContext callbackContext) {
		DistimoSDK.onInAppPurchase(productID, orderID);
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void logInAppPurchaseRefunded(String productID, String orderID, CallbackContext callbackContext) {
		DistimoSDK.onInAppPurchaseRefunded(productID, orderID);
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void logExternalPurchaseWithCurrency(String productID, String currency, double price, int quantity, CallbackContext callbackContext) {
		DistimoSDK.onExternalPurchase(productID, currency, price, quantity);
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void logBannerClick(String publisher, CallbackContext callbackContext) {
		DistimoSDK.onBannerClick(publisher);
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void setUserID(String userID, CallbackContext callbackContext) {
		DistimoSDK.setUserID(userID);
		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
	}
	
	private void openAppLink(String applinkHandle, String campaignHandle, CallbackContext callbackContext) {
		DistimoSDK.openAppLink(applinkHandle, campaignHandle, cordova.getActivity());
	}
}
