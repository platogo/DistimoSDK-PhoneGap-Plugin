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

import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Looper;
import android.util.Log;

final class AppLinkManager {
	
	private final static String TAG				= "EventManager";
	private static boolean redirecting			= false;
	
	private static Activity currentActivity;
	
	static void openAppLink(String applinkHandle, String campaignHandle, Activity activity) {
		if (redirecting) {
			//Only redirect once
			return;
		}
		
		if (Utils.DEBUG) { Log.i(TAG, "openAppLink(" + (applinkHandle != null ? applinkHandle : "NULL") + ", " + (campaignHandle != null ? campaignHandle : "NULL") + ")"); }
		
		if (activity != null && applinkHandle != null && applinkHandle.length() > 0) {
			currentActivity = activity;
			
			StringBuilder builder = new StringBuilder("http://app.lk/").append(applinkHandle).append("/redirect");
			if (campaignHandle != null) {
				builder.append("?x=").append(campaignHandle);
			}
			
			redirecting = true;

			AppLinkTask task = new AppLinkTask();
			task.execute(builder.toString());
		}
	}
	
	private static void showAppLink(final String applinkUrl) {
		AppLinkManager.showAppLink(applinkUrl, null);
	}
	private static void showAppLink(final String applinkUrl, final String fallbackUrl) {
		if (Utils.DEBUG) { Log.i(TAG, "showAppLink URL: " + (applinkUrl != null ? applinkUrl : "NULL")); }
		
		if (applinkUrl != null) {
			//Check if this is the main thread so it can be used in the runnable
			final boolean isMainLooper = (Looper.myLooper() == Looper.getMainLooper());
			
			Runnable action = new Runnable() {
				public void run() {
					//First try the applinkUrl, if that failed try the fallbackUrl if it exists
					if (!AppLinkManager.startActivity(applinkUrl)) {
						if (Utils.DEBUG) { Log.i(TAG, "showAppLink Fallback: " + (fallbackUrl != null ? fallbackUrl : "NULL")); }
						
						if (fallbackUrl != null) {
							AppLinkManager.startActivity(fallbackUrl);
						}
					}
					
					if (!isMainLooper) {
						//Different thread, notify calling thread
						try {
							this.notify();
						} catch (IllegalMonitorStateException e) {
							if (Utils.DEBUG) { e.printStackTrace(); }
						}
					}
				}
			};
			
			if (isMainLooper) {
				//Already on the UI thread, just run it
				action.run();
			} else {
				//Not the UI thread, run it on the UI thread and wait until done
				synchronized (action) {
					currentActivity.runOnUiThread(action);
					try {
						action.wait();
					} catch (InterruptedException e) {
						if (Utils.DEBUG) { e.printStackTrace(); }
					}
				}
			}
		}
		
		currentActivity = null;
		redirecting = false;
	}
	
	private static boolean startActivity(final String url) {
		Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
		ResolveInfo info = currentActivity.getPackageManager().resolveActivity(intent, 0);
		if (info != null) {
			//There is an activity available, show it!
			currentActivity.startActivity(intent);
			
			return true;
		}
		
		return false;
	}
	
	private static final class AppLinkTask extends AsyncTask<String, String, Boolean> {
		
		private String applinkUrl;
		private String marketUrl;
		
		@Override
		protected void onPreExecute() {
			super.onPreExecute();
		}
		
		@Override
	    protected Boolean doInBackground(String... uri) {
			if (Utils.DEBUG) { Log.i("AppLinkTask", "doInBackground()"); }
			
			Boolean result = false;
			
			// HTTP connection reuse which was buggy before FROYO
			if (Build.VERSION.SDK_INT < 8) { //Build.VERSION_CODES.FROYO
		        System.setProperty("http.keepAlive", "false");
		    }
			
			if (uri != null) {
				this.applinkUrl = uri[0];
				
				if (Utils.DEBUG) { Log.i("AppLinkTask", "Calling: " + this.applinkUrl); }
				
				HttpURLConnection urlConnection = null;
				try {
					URL url = new URL(this.applinkUrl);
					urlConnection = (HttpURLConnection) url.openConnection();
					urlConnection.setInstanceFollowRedirects(false);
					urlConnection.setRequestMethod("GET");
					urlConnection.connect();
					
					if (urlConnection.getResponseCode() == HttpURLConnection.HTTP_MOVED_TEMP) { //302
						this.marketUrl = urlConnection.getHeaderField("Location");
						if (this.marketUrl != null) {
							result = true;
						}
					}
				} catch (final MalformedURLException mue) {
					if (Utils.DEBUG) { Log.e("AppLinkTask", "Malformed URL: " + this.applinkUrl); }
				} catch (final Throwable t) {
					if (Utils.DEBUG) { t.printStackTrace(); }
				} finally {
					if (urlConnection != null) {
						urlConnection.disconnect();
					}
				}
			}
			
			return result;
	    }
		
	    @Override
	    protected void onPostExecute(Boolean result) {
	    	if (Utils.DEBUG) { Log.i("AppLinkTask", "onPostExecute()"); }
			
	        super.onPostExecute(result);
	        
	        if (result == true) {
	        	if (Utils.DEBUG) { Log.i("AppLinkTask", "302 received, opening Market URL"); }
	        	
	        	AppLinkManager.showAppLink(this.marketUrl, this.applinkUrl);
	        } else {
	        	if (Utils.DEBUG) { Log.w("AppLinkTask", "Redirect failed, opening AppLink URL"); }
	        	
	        	AppLinkManager.showAppLink(this.applinkUrl);
	        }
	        
	        this.applinkUrl = null;
	        this.marketUrl = null;
	    }
	}
	
}
