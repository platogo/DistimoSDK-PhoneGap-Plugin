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
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.Thread.UncaughtExceptionHandler;

import android.content.Context;
import android.content.SharedPreferences;

import com.distimo.sdk.EventManager.Event;

/**
 * UncaughtExceptionHandler used to catch and store exceptions that are caused by the Distimo SDK
 *  Found exceptions are stored in the SharedPreferences and sent on the next run of the application 
 * 
 * @author arne
 */
final class DistimoExceptionHandler implements UncaughtExceptionHandler {
	
	private final static String PREFERENCES_FILE_NAME			= "2fDSTrGok9na2QiMvxEs";
	private final static String PREFERENCES_STACKTRACE_KEY		= "eKh7DsU903Q7m81KjBeB";
	
	private final UncaughtExceptionHandler defaultUncaughtExceptionHandler;
	private final SharedPreferences preferences;
	
	DistimoExceptionHandler(Context context) {
		this.defaultUncaughtExceptionHandler = Thread.getDefaultUncaughtExceptionHandler();
		this.preferences = context.getSharedPreferences(PREFERENCES_FILE_NAME, Context.MODE_PRIVATE);
		
		// Check for a stored crash in SharedPreferences
		if (this.preferences != null) {
			
			String stackTrace = this.preferences.getString(PREFERENCES_STACKTRACE_KEY, null);
			
			if (stackTrace != null) {
				// Send a DistimoException event with the stack trace as POST data
				Event exceptionEvent = new Event("DistimoException", null, stackTrace);
				DistimoSDK.sendEvent(exceptionEvent);
				
				// Remove the stack trace from SharedPreferences
				this.preferences.edit().remove(PREFERENCES_STACKTRACE_KEY).commit();
			}
		}
	}

	public void uncaughtException(Thread thread, Throwable ex) {
		if (Utils.DEBUG) { ex.printStackTrace(); }
		
		// Check for DistimoSDK involvement
		if (this.preferences != null) {
			
			// Try to find a class from the com.distimo.sdk package in the stack trace of
			// the exception itself or any of the exceptions that caused it 
			Throwable cause = ex;
			Throwable exResult = null;
			
			while (cause != null && exResult == null) {
				if (cause.getStackTrace() != null) {
					for (StackTraceElement element : cause.getStackTrace()) {
						if (element.getClassName().startsWith("com.distimo.sdk.")) {
							// DistimoSDK crash, break from loop
							exResult = cause;
							break;
						}
					}
				}
				cause = cause.getCause();
			}
			
			if (exResult != null) {
				StringWriter sw = null;
				PrintWriter pw = null;
				
				try {
					// Construct stack trace
					sw = new StringWriter();
					pw = new PrintWriter(sw);
					exResult.printStackTrace(pw);
					String strackTrace = sw.toString();
					
					// DistimoSDK crash, save to SharedPreferences
					this.preferences.edit().putString(PREFERENCES_STACKTRACE_KEY, strackTrace).commit();
				} catch (Exception e) {
					//Ignore errors
				} finally {
					if (pw != null) {
						pw.close();
					}
					try {
						if (sw != null) {
							sw.close();
						}
					} catch (IOException e) {
						//Ignore
					}
				}
			}
		}
		
		// Call the other uncaught exception handler if it exists
		if (this.defaultUncaughtExceptionHandler != null) {
			this.defaultUncaughtExceptionHandler.uncaughtException(thread, ex);
		}
	}
	
}
