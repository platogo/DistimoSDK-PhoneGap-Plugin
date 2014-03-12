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

import java.io.BufferedOutputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteException;
import android.database.sqlite.SQLiteOpenHelper;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

final class EventManager {

	private final static String TAG				= "EventManager";
	private final static Object LOCK_OBJECT		= new Object(); 
	
	private final static long INITIAL_DELAY		= 1000;
	private final static long MAX_DELAY			= 32000;
	
	private static boolean initialized			= false;
	private static long delay					= INITIAL_DELAY;
	
	private static Handler eventHandler;
	
    private static EventStorage eventStorage;
    private static EventSenderTask eventSender;
    private static ArrayList<Event> eventsList;

	// -- Initialization -- //
    
    static void initialize(final Context context) {
		synchronized (LOCK_OBJECT) {
			if (Utils.DEBUG) { Log.i(TAG, "initialize()"); }

			initialized = true;
			
			//Create the eventHandler thread that should contain all calls to store/remove/send
			HandlerThread handlerThread = new HandlerThread(TAG);
			handlerThread.start();
			eventHandler = new Handler(handlerThread.getLooper());
			
			//Create the eventStorage on the eventHandler thread and get the stored events
			eventHandler.post(new Runnable() {
				public void run() {
					try {
						eventStorage = new EventStorage(context);
						eventsList = eventStorage.getEvents();
					} catch (Throwable t) {
						if (Utils.DEBUG) { t.printStackTrace(); }
					} finally {
						//Make sure the events list is created, event when the storage failed 
						if (eventsList == null) {
							eventsList = new ArrayList<Event>();
						}
					}

					if (Utils.DEBUG) { Log.i(TAG, "Found " + eventsList.size() + " event(s)"); }

					sendNextEvent();
				}
			});
		}
	}
    
	// -- Protected methods -- //
    
    static void logEvent(final Event event) {
		synchronized (LOCK_OBJECT) {
			if (Utils.DEBUG) { Log.e(TAG, "logEvent(" + event.name + ")"); }
			
			if (!initialized) {
				return;
			}
			
			//Store and (optionally) send the event on the eventHandler thread
			eventHandler.post(new Runnable() {
				public void run() {
					storeEvent(event);

					if (eventsList.size() == 1) {
						sendEvent(event);
					}
				}
			});
		}
    }
    
	// -- Private methods -- //
    
    private static void storeEvent(Event event) {
    	if (Utils.DEBUG) { Log.i(TAG, "storeEvent(" + event.name + ")"); }
    	
    	try {
    		eventStorage.storeEvent(event);
    	} catch (Throwable t) {
    		if (Utils.DEBUG) { t.printStackTrace(); }
    	}
    	
    	eventsList.add(event);
    }
    
    private static void removeEvent(Event event) {
    	if (Utils.DEBUG) { Log.i(TAG, "removeEvent(" + event.name + ")"); }
    	
    	try {
    		eventStorage.removeEvent(event);
    	} catch (Throwable t) {
    		if (Utils.DEBUG) { t.printStackTrace(); }
    	}
    	
    	eventsList.remove(event);
    }
    
	private static void sendEvent(Event event) {
		if (Utils.DEBUG) { Log.i(TAG, "sendEvent(" + event.name + ")"); }
		
		eventSender = new EventSenderTask();
		eventSender.execute(event);
	}
	
	private static void sendNextEvent() {
		if (Utils.DEBUG) { Log.i(TAG, "sendNextEvent()"); }
		
		if (eventsList.size() > 0) {
			sendEvent(eventsList.get(0));
		} else {
			if (Utils.DEBUG) { Log.i(TAG, "No more events to send"); }
		}
	}
	
	// -- Callback methods -- //
	
	private static void onEventSent(final Event event) {
		synchronized (LOCK_OBJECT) {
			if (Utils.DEBUG) { Log.i(TAG, "onEventSent(" + event.name + ")"); }

			eventSender = null;

			delay = INITIAL_DELAY;

			//Remove and send the event on the eventHandler thread
			eventHandler.post(new Runnable() {
				public void run() {
					removeEvent(event);
					sendNextEvent();
				}
			});
		}
	}
	
	private static void onEventFailed(final Event event) {
		synchronized (LOCK_OBJECT) {
			if (Utils.DEBUG) { Log.i(TAG, "onEventFailed(" + event.name + ")"); }

			eventSender = null;

			delay = Math.min(delay * 2, MAX_DELAY);

			//Send the event on the eventHandler thread
			eventHandler.post(new Runnable() {
				public void run() {
					sendNextEvent();
				}
			});
		}
	}
	
	// INTERNAL CLASS EVENT //
	
	static final class Event {
		
		private long id;
		private String name;
		private Map<String, String> params;
		private String postData;
		private long timestamp;
		private String checksum;
		private String bundleID;
		private String appVersion;
		private String sdkVersion;
		
		/**
		 * Use this constructor to create a new event.
		 * The time, bundleID and appVersion will automatically be set.
		 */
		Event(String name, Map<String, String> params, String postData) {
			this(-1, name, params, postData, System.currentTimeMillis(), DistimoSDK.bundleID, DistimoSDK.appVersion, DistimoSDK.VERSION);
		}
		
		/**
		 * Use this constructor for a stored event.
		 */
		Event(long id, String name, Map<String, String> params, String postData, long timestamp, String bundleID, String appVersion, String sdkVersion) {
			if (Utils.DEBUG) { Log.i(TAG, "Event()"); }
			
			this.id = id;
			this.name = name;
			this.params = params;
			this.postData = postData;
			this.timestamp = timestamp;
			this.bundleID = bundleID;
			this.appVersion = appVersion;
			this.sdkVersion = sdkVersion;
			this.calculateChecksum();
		}
		
		void setId(long id) {
			this.id = id;
		}
		
		String urlParamString() {
			if (Utils.DEBUG) { Log.i(TAG, "Event.urlParamString()"); }
			
			String result = this.urlParamPayload();
			result += "&ct=" + System.currentTimeMillis();
			result += "&cs=" + this.checksum;
			
			return result;
		}
		
		private String urlParamPayload() {
			if (Utils.DEBUG) { Log.i(TAG, "Event.urlParamPayload()"); }
			
			String result = "en=" + this.name;
			
			result += "&lt=" + this.timestamp;
			result += "&av=" + this.appVersion;
			result += "&sv=" + this.sdkVersion;
			result += "&bu=" + this.bundleID;
			result += "&oi=" + DistimoSDK.publicKey;
			result += "&uu=" + DistimoSDK.uniqueUserID;
			result += "&hu=" + DistimoSDK.uniqueHardwareID;
			result += "&es=" + "a";
			
			if (this.params != null) {
				try {
					result += "&ep=" + URLEncoder.encode(this.parameterString(), "UTF-8");
				} catch (final UnsupportedEncodingException uee) {
					if (Utils.DEBUG) { uee.printStackTrace(); }
				}
			}
			
			return result;
		}
		
		private String parameterString() {
			if (this.params != null) {
				if (Utils.DEBUG) { Log.i(TAG, "Event.parameterString()"); }

				String result = "";

				for (String key : this.params.keySet()) {
					try {
						String value = URLEncoder.encode(this.params.get(key), "UTF-8");
						key = URLEncoder.encode(key, "UTF-8");
						if (result.length() > 0) {
							result += ";";
						}
						result += key + "=" + value;
					} catch (final UnsupportedEncodingException uee) {
						if (Utils.DEBUG) { uee.printStackTrace(); }
						continue;
					}
				}

				return result;
			}
			
			return null;
		}
		
		private void calculateChecksum() {
			if (Utils.DEBUG) { Log.i(TAG, "Event.calculateChecksum()"); }
			
			String getPayload = Utils.md5(this.urlParamPayload());
			if (Utils.DEBUG) { Log.i(TAG, "Hashing " + this.urlParamPayload() + " --> " + getPayload); }
			
			String payload = null;
			
			if (this.postData != null) {
				String postPayload = Utils.md5(this.postData);
				if (Utils.DEBUG) { Log.i(TAG, "Hashing " + this.postData + " --> " + postPayload); }
				
				payload = Utils.md5(getPayload + postPayload);
				if (Utils.DEBUG) { Log.i(TAG, "Hashing " + getPayload + postPayload + " --> " + payload); }
			} else {
				payload = getPayload;
			}
			
			String result = Utils.md5(payload + DistimoSDK.privateKey);
			if (Utils.DEBUG) { Log.i(TAG, "Hashing " + payload + DistimoSDK.privateKey + " --> " + result); }
			
			this.checksum = result;
		}
	}
	
	private static final class EventSenderTask extends AsyncTask<Event, String, Boolean> {
		
		private final static String EVENT_URL		= "https://a.distimo.mobi/e/";
		private Event event							= null;
		
		@Override
		protected void onPreExecute() {
			super.onPreExecute();
		}
		
		@Override
	    protected Boolean doInBackground(Event... uri) {
			if (Utils.DEBUG) { Log.i(TAG, "EventSenderTask.doInBackground(), delaying for " + delay + "ms"); }
			
			try {
				Thread.sleep(delay);
			} catch (InterruptedException e) {
				if (Utils.DEBUG) { e.printStackTrace(); }
			}
			
			Boolean result = false;
			
			// HTTP connection reuse which was buggy before FROYO
			if (Build.VERSION.SDK_INT < 8) { //Build.VERSION_CODES.FROYO
		        System.setProperty("http.keepAlive", "false");
		    }
			
			if (uri != null) {
				this.event = uri[0];
				
				final String urlString = EVENT_URL + "?" + this.event.urlParamString();
				if (Utils.DEBUG) { Log.i("EventSenderTask", "Calling: " + urlString); }
				
				HttpURLConnection urlConnection = null;
				try {
					URL url = new URL(urlString);
					urlConnection = (HttpURLConnection) url.openConnection();
					
					if (this.event.postData != null) {
						if (Utils.DEBUG) { Log.i(TAG, "Sending POST data: " + this.event.postData); }
						
						byte[] buffer = this.event.postData.getBytes();
						
						if (buffer != null) {
							urlConnection.setDoOutput(true);
							urlConnection.setRequestMethod("POST");
							urlConnection.setFixedLengthStreamingMode(buffer.length);

							OutputStream out = new BufferedOutputStream(urlConnection.getOutputStream());
							out.write(buffer, 0, buffer.length);
							out.close();
						}
					} else {
						urlConnection.setRequestMethod("GET");
					}
					
					urlConnection.connect();
					
					if (urlConnection.getResponseCode() == HttpURLConnection.HTTP_OK) {
						result = true;
					}
				} catch (final MalformedURLException mue) {
					if (Utils.DEBUG) { Log.e(TAG, "Malformed URL: " + urlString); }
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
	    	if (Utils.DEBUG) { Log.i(TAG, "EventSenderTask.onPostExecute()"); }
			
	        super.onPostExecute(result);
	        
	        if (result == true) {
	        	if (Utils.DEBUG) { Log.i(TAG, "Event sent"); }
	        	
	        	EventManager.onEventSent(event);
	        } else {
	        	if (Utils.DEBUG) { Log.w(TAG, "Event failed"); }
	        	
	        	EventManager.onEventFailed(event);
	        }
	        
	        this.event = null;
	    }
	}
	
	private static final class EventStorage extends SQLiteOpenHelper {
		
		private static final int DATABASE_VERSION						= 3;
		private static final String DATABASE_NAME						= "iUMZo9KH0GINHA0grXdb";
		
		private static final String TABLE_EVENTS						= "m1IIXjAg5dqwkc1qBttt";
		private static final String COLUMN_EVENT_ID						= "_id";
		private static final String COLUMN_EVENT_NAME					= "E2JM7QGIpG60aWeT6a2Z";
		private static final String COLUMN_EVENT_TIMESTAMP				= "rtAHrQshIqQgGaSiYdYq";
		private static final String COLUMN_EVENT_BUNDLE_ID				= "rx2bp71JtmNNu0eXtWkB";
		private static final String COLUMN_EVENT_APPVERSION				= "jH8jWi0okVm2Q851uonz";
		private static final String COLUMN_EVENT_SDKVERSION				= "fMcxuAIZI0PONUrKi67t";
		private static final String COLUMN_EVENT_SDKVERSION_CONSTRAINT	= "oU8Uiw7zWkIhaqu1AvFN";
		private static final String COLUMN_EVENT_POSTDATA				= "YkWrccIQbLjJeOpjVUdD";
		
		private static final String TABLE_EVENT_PARAMETERS				= "z3nmDV24U0qFWm7X4pqU";
		private static final String INDEX_EVENT_PARAMETERS				= "S6NFKoXGqBqw9DyWbYgA";
		private static final String COLUMN_EVENT_PARAMETERS_EVENT_ID	= "BChtZqHo55haUvWaHAjE";
		private static final String COLUMN_EVENT_PARAMETERS_KEY			= "Nbxub6tYsC4g5DbFbgZN";
		private static final String COLUMN_EVENT_PARAMETERS_VALUE		= "t9PSswmXu2sE5PVA6Zq4";
		
		private static final String EVENTS_CREATE = 
				"CREATE TABLE " + TABLE_EVENTS + " ("
				+ COLUMN_EVENT_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, "
				+ COLUMN_EVENT_NAME + " TEXT NOT NULL, "
				+ COLUMN_EVENT_TIMESTAMP + " LONG, "
				+ COLUMN_EVENT_BUNDLE_ID + " TEXT NOT NULL, "
				+ COLUMN_EVENT_APPVERSION + " TEXT NOT NULL, "
				+ COLUMN_EVENT_SDKVERSION + " TEXT NOT NULL, "
				+ COLUMN_EVENT_POSTDATA + " TEXT);";
		
		private static final String EVENTS_ADD_SDKVERSION_COLUMN = 
				"ALTER TABLE " + TABLE_EVENTS + " "
				+ "ADD " + COLUMN_EVENT_SDKVERSION + " TEXT NOT NULL "
				+ "CONSTRAINT " + COLUMN_EVENT_SDKVERSION_CONSTRAINT + " DEFAULT '';";
		
		private static final String EVENTS_ADD_POSTDATA_COLUMN =
				"ALTER TABLE " + TABLE_EVENTS + " "
				+ "ADD " + COLUMN_EVENT_POSTDATA + " TEXT;";
		
		private static final String EVENT_PARAMETERS_CREATE =
				"CREATE TABLE " + TABLE_EVENT_PARAMETERS + " ("
				+ COLUMN_EVENT_PARAMETERS_EVENT_ID + " INTEGER, "
				+ COLUMN_EVENT_PARAMETERS_KEY + " TEXT NOT NULL, "
				+ COLUMN_EVENT_PARAMETERS_VALUE + " TEXT NOT NULL);";
		
		private static final String EVENT_PARAMETERS_CREATE_INDEX =
				"CREATE INDEX " + INDEX_EVENT_PARAMETERS + " ON "
				+ TABLE_EVENT_PARAMETERS + " ("
				+ COLUMN_EVENT_PARAMETERS_EVENT_ID + ", "
				+ COLUMN_EVENT_PARAMETERS_KEY + ");";
		
		EventStorage(Context context) {
			super(context, DATABASE_NAME, null, DATABASE_VERSION);
		}
		
		@Override
		public void onCreate(SQLiteDatabase db) {
			if (Utils.DEBUG) { Log.i(TAG, "EventStorage.onCreate()"); }
			
			if (Utils.DEBUG) { Log.i(TAG, "Executing statement: " + EVENTS_CREATE); }
			db.execSQL(EVENTS_CREATE);
			
			if (Utils.DEBUG) { Log.i(TAG, "Executing statement: " + EVENT_PARAMETERS_CREATE); }
			db.execSQL(EVENT_PARAMETERS_CREATE);
			
			if (Utils.DEBUG) { Log.i(TAG, "Executing statement: " + EVENT_PARAMETERS_CREATE_INDEX); }
			db.execSQL(EVENT_PARAMETERS_CREATE_INDEX);
		}
		
		@Override
		public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
			if (Utils.DEBUG) { Log.i(TAG, "EventStorage.onUpgrade() " + oldVersion + " -> " + newVersion); }
			
			if (oldVersion < 2 && newVersion >= 2) {
				if (Utils.DEBUG) { Log.i(TAG, "Executing statement: " + EVENTS_ADD_SDKVERSION_COLUMN); }
				
				db.execSQL(EVENTS_ADD_SDKVERSION_COLUMN);
			}
			
			if (oldVersion < 3 && newVersion >= 3) {
				if (Utils.DEBUG) { Log.i(TAG, "Executing statement: " + EVENTS_ADD_POSTDATA_COLUMN); }
				
				db.execSQL(EVENTS_ADD_POSTDATA_COLUMN);
			}
		}
		
		boolean storeEvent(Event event) {
			if (Utils.DEBUG) { Log.i(TAG, "EventStorage.storeEvent(" + event.name + " (" + event.id + "))"); }
			
			//Assume failure
			boolean result = false;
			
			SQLiteDatabase database = null;
			try {
				database = this.getWritableDatabase();
			} catch (final SQLiteException sqle) {
				if (Utils.DEBUG) { sqle.printStackTrace(); }
			}
			
			if (database != null) {
				try {
					database.beginTransaction();

					ContentValues eventValues = new ContentValues();
					eventValues.put(COLUMN_EVENT_NAME, event.name);
					eventValues.put(COLUMN_EVENT_TIMESTAMP, event.timestamp);
					eventValues.put(COLUMN_EVENT_BUNDLE_ID, event.bundleID);
					eventValues.put(COLUMN_EVENT_APPVERSION, event.appVersion);
					eventValues.put(COLUMN_EVENT_SDKVERSION, event.sdkVersion);
					eventValues.put(COLUMN_EVENT_POSTDATA, event.postData);
					long eventID = database.insertOrThrow(TABLE_EVENTS, null, eventValues);
					if (eventID != -1) {
						//First step succeeded, now assume success
						result = true;
						
						if (event.params != null) {
							for (String key : event.params.keySet()) {
								String value = event.params.get(key);
								ContentValues parameterValues = new ContentValues();
								parameterValues.put(COLUMN_EVENT_PARAMETERS_EVENT_ID, (int)eventID);
								parameterValues.put(COLUMN_EVENT_PARAMETERS_KEY, key);
								parameterValues.put(COLUMN_EVENT_PARAMETERS_VALUE, value);
								long parameterID = database.insertOrThrow(TABLE_EVENT_PARAMETERS, null, parameterValues);
								if (parameterID == -1) {
									//The insert failed, set the result to false and break
									result = false;
									break;
								}
							}
						}
						
						if (result == true) {
							//All went well, set the transaction as successful
							database.setTransactionSuccessful();
							
							//Set the ID to the event
							event.setId(eventID);
						}
					}
				} catch (final SQLException se) {
					if (Utils.DEBUG) { se.printStackTrace(); }
					result = false;
				}
				
				//End the transaction
				database.endTransaction();
			}
			
			this.close();
			
			return result;
		}
		
		boolean removeEvent(Event event) {
			if (Utils.DEBUG) { Log.i(TAG, "EventStorage.removeEvent(" + event.name + " (" + event.id + "))"); }
			
			//Assume failure
			boolean result = false;
			
			SQLiteDatabase database = null;
			try {
				database = this.getWritableDatabase();
			} catch (final SQLiteException sqle) {
				if (Utils.DEBUG) { sqle.printStackTrace(); }
			}
			
			if (database != null) {
				try {
					database.beginTransaction();
					
					//Delete the event
					String whereClause = COLUMN_EVENT_ID + " = " + event.id;
					database.delete(TABLE_EVENTS, whereClause, null);
					
					//Delete the event parameters
					whereClause = COLUMN_EVENT_PARAMETERS_EVENT_ID + " = " + event.id;
					database.delete(TABLE_EVENT_PARAMETERS, whereClause, null);
					
					//All went well, set the transaction as successful
					database.setTransactionSuccessful();
					
					result = true;
				} catch (SQLException se) {
					if (Utils.DEBUG) { se.printStackTrace(); }
				}
				
				database.endTransaction();
			}
			
			this.close();
			
			return result;
		}
		
		ArrayList<Event> getEvents() {
			if (Utils.DEBUG) { Log.i(TAG, "EventStorage.getEvents()"); }
			ArrayList<Event> events = new ArrayList<Event>();
			
			SQLiteDatabase database = null;
			try {
				database = this.getReadableDatabase();
			} catch (final SQLiteException sqle) {
				if (Utils.DEBUG) { sqle.printStackTrace(); }
			}

			if (database != null) {
				final String[] allColumns = {
						COLUMN_EVENT_ID,
						COLUMN_EVENT_NAME,
						COLUMN_EVENT_TIMESTAMP,
						COLUMN_EVENT_BUNDLE_ID,
						COLUMN_EVENT_APPVERSION,
						COLUMN_EVENT_SDKVERSION,
						COLUMN_EVENT_POSTDATA};

				Cursor cursor = database.query(TABLE_EVENTS, allColumns, null, null, null, null, COLUMN_EVENT_ID);
				if (cursor != null) {
					cursor.moveToFirst();

					while (!cursor.isAfterLast()) {
						int eventID = cursor.getInt(0);
						String name = cursor.getString(1);
						long timestamp = cursor.getLong(2);
						String bundleID = cursor.getString(3);
						String appVersion = cursor.getString(4);
						String sdkVersion = cursor.getString(5);
						String postData = null;
						if (!cursor.isNull(6)) {
							postData = cursor.getString(6);
						}
						Map<String, String> params = this.getEventParameters(database, eventID);

						Event event = new Event(eventID, name, params, postData, timestamp, bundleID, appVersion, sdkVersion);
						events.add(event);

						cursor.moveToNext();
					}

					cursor.close();
				}
				
				this.close();
			}
			
			return events;
		}
		
		Map<String, String> getEventParameters(SQLiteDatabase database, int eventID) {
			HashMap<String, String> params = new HashMap<String, String>();
			
			final String[] allColumns = {
					COLUMN_EVENT_PARAMETERS_EVENT_ID,
					COLUMN_EVENT_PARAMETERS_KEY,
					COLUMN_EVENT_PARAMETERS_VALUE };

			final String selection = COLUMN_EVENT_PARAMETERS_EVENT_ID + " = " + eventID;

			Cursor cursor = database.query(TABLE_EVENT_PARAMETERS, allColumns, selection, null, null, null, null);
			if (cursor != null) {
				cursor.moveToFirst();

				while (!cursor.isAfterLast()) {
					String key = cursor.getString(1);
					String value = cursor.getString(2);

					params.put(key, value);

					cursor.moveToNext();
				}
				
				cursor.close();
			}
			
			return params;
		}
	}
}
