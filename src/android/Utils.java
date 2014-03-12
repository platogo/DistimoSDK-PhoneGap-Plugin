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

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.annotation.SuppressLint;
import android.os.Build;
import android.util.Base64;
import android.util.Log;

final class Utils {
	
	//Set this to true if you want to enable debugging (or set it to BuildConfig.DEBUG for convenience)
	public final static boolean DEBUG = false;
	
	private final static char[] HEX_DIGITS = "0123456789abcdef".toCharArray();
	private final static String TAG = "Utils";
	
	// -- Key/value -- //
	
	static Map<String, String> keyValueStringToMap(String query) {
		if (Utils.DEBUG) { Log.i(TAG, "keyValueStringToMap()"); }
		
        // Create Map to store the parameters
        Map<String, String> result = new HashMap<String, String>();

        // Parse the query string, extracting the relevant data
        String[] params = query.split("&"); // $NON-NLS-1$
        for (String param : params)
        {
            String[] pair = param.split("="); // $NON-NLS-1$
            if (pair.length == 2) {
            	if (Utils.DEBUG) { Log.i(TAG, "Found " + pair[0] + "=" + pair[1]); }
            	result.put(pair[0], pair[1]);
            } else {
            	if (Utils.DEBUG) { Log.w(TAG, "Skipping " + param); }
            }
        }
        
        return result;
    }
	
	// -- Hashing -- //
	
	static String md5(String s) {
		if (Utils.DEBUG) { Log.i(TAG, "md5()"); }
		
		String result = "";
		
		MessageDigest m = null;
		try {
			m = MessageDigest.getInstance("MD5");
			m.update(s.getBytes(),0,s.length());
			result = byteArrayToHexString(m.digest());
		} catch (final NoSuchAlgorithmException nsae) {
			if (Utils.DEBUG) { nsae.printStackTrace(); }
		}
		
		return result;
	}
	
	// -- Hex -- //
	
	static byte[] hexStringToByteArray(String s) {
	    int len = s.length();
	    byte[] data = new byte[len / 2];
	    for (int i = 0; i < len; i += 2) {
	        data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4) + Character.digit(s.charAt(i+1), 16));
	    }
	    return data;
	}
	
	static String byteArrayToHexString(byte[] data) {
	    char[] chars = new char[data.length * 2];
	    for (int i = 0; i < data.length; i++) {
	        chars[i * 2] = HEX_DIGITS[(data[i] >> 4) & 0xf];
	        chars[i * 2 + 1] = HEX_DIGITS[data[i] & 0xf];
	    }
	    return new String(chars);
	}
	
	// -- Base64 -- //
	
	static String base64Encode(String s, boolean isHex) {
		byte[] data;
		if (isHex == true) {
			data = Utils.hexStringToByteArray(s);
		} else {
			data = s.getBytes();
		}
		
		return base64Encode(data);
	}
	
	@SuppressLint({ "NewApi", "InlinedApi" })
	static String base64Encode(byte[] data) {
		String result = null;
		
		if (Build.VERSION.SDK_INT < 8) { //Build.VERSION.FROYO
			try {
				result = OldBase64.encodeBytes(data, OldBase64.URL_SAFE).replace("=", "");
			} catch (final IOException ioe) {
				if (Utils.DEBUG) { ioe.printStackTrace(); }
			}
		} else {
			result = Base64.encodeToString(data, Base64.NO_PADDING | Base64.URL_SAFE | Base64.NO_WRAP);
		}
		
		return result;
	}
	
	// -- JSON -- //
	
	static JSONArray parseToJSON(ArrayList<Entry<String, Object>> array) {
		JSONArray result = new JSONArray();
		
		for (Entry<String, Object> entry : array) {
			result.put(parseToJSON(entry.getKey(), entry.getValue()));
		}
		
		return result;
	}
	
	static JSONObject parseToJSON(String key, Object value) {
		JSONObject result = new JSONObject();
		
		try {
			result.put(key, value);
		} catch (JSONException e) {
			if (Utils.DEBUG) { e.printStackTrace(); }
		}
		
		return result;
	}
	
	// -- Interface implementations -- //
	
	final static class EntryImpl<K, V> implements Map.Entry<K, V> {
		private final K key;
		private V value;

		public EntryImpl(K key, V value) {
			this.key = key;
			this.value = value;
		}

		public K getKey() {
			return key;
		}

		public V getValue() {
			return value;
		}

		public V setValue(V value) {
			V old = this.value;
			this.value = value;
			return old;
		}
	}	
}
