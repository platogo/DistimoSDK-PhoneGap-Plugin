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

using Microsoft.Phone.Controls;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.IO.IsolatedStorage;
using System.Net;
using System.Text;
using ProtoBuf;
using Microsoft.Phone.Shell;
using System.Windows;
using System.Windows.Threading;
using System.ComponentModel;
using System.Threading;

namespace Distimo
{
    internal sealed class EventManager
    {
        private static EventSender eventSender;
        private static List<Event> eventsList;
        private static Boolean isEnabled;

        private EventManager() { }

        internal static void initialize()
        {
            //Listen for application lifetime events
            PhoneApplicationService.Current.Activated += new EventHandler<ActivatedEventArgs>(Application_Activated);
            PhoneApplicationService.Current.Deactivated += new EventHandler<DeactivatedEventArgs>(Application_Deactivated);
            PhoneApplicationService.Current.Closing += new EventHandler<ClosingEventArgs>(Application_Closing);

            //Listen for unhandled exceptions
            Application.Current.UnhandledException += new EventHandler<ApplicationUnhandledExceptionEventArgs>(Application_UnhandledException);

            //Enable (in case this method is called after Activated)
            setEnabled(true);
        }

        internal static void setEnabled(Boolean enabled)
        {
            if (enabled && !isEnabled)
            {
                //Read events from storage
                eventsList = EventStorage.getEvents();

                if (eventsList.Count > 0)
                {
                    sendNextEvent();
                }

                isEnabled = true;
            }
            else if (!enabled && isEnabled)
            {
                //Stop current eventSender
                if (eventSender != null)
                {
                    eventSender.cancel();
                    eventSender = null;
                }

                //Store events to storage
                EventStorage.storeEvents(eventsList);
                eventsList = null;

                isEnabled = false;
            }
        }

        internal static void logEvent(Event e)
        {
            Utils.log("logEvent(" + e.name + ")");

            storeEvent(e);

            if (isEnabled && eventsList.Count == 1)
            {
                sendEvent(e);
            }
        }

        //Event handlers

        static void Application_Activated(object sender, ActivatedEventArgs e)
        {
            Utils.log("Application_Activated");

            //Enable event manager
            EventManager.setEnabled(true);
        }

        static void Application_Deactivated(object sender, DeactivatedEventArgs e)
        {
            Utils.log("Application_Deactivated");

            //Disable event manager
            EventManager.setEnabled(false);
        }

        static void Application_Closing(object sender, ClosingEventArgs e)
        {
            Utils.log("Application_Closing");

            //Disable event manager
            EventManager.setEnabled(false);
        }

        static void Application_UnhandledException(object sender, ApplicationUnhandledExceptionEventArgs e)
        {
            Utils.log("Application_UnhandledException");

            //Disable event manager
            EventManager.setEnabled(false);
        }

        // Private methods

        private static void storeEvent(Event e)
        {
            Utils.log("storeEvent(" + e.name + ")");

            if (isEnabled)
            {
                //Store in memory
                eventsList.Add(e);
            }
            else
            {
                //Store in persistent storage
                List<Event> tempList = EventStorage.getEvents();
                tempList.Add(e);
                EventStorage.storeEvents(tempList);
            }
        }

        private static void removeEvent(Event e)
        {
            Utils.log("removeEvent(" + e.name + ")");

            if (isEnabled)
            {
                //Remove from memory
                eventsList.Remove(e);
            }
            else
            {
                //Remove from persistent storage
                List<Event> tempList = EventStorage.getEvents();
                tempList.Remove(e);
                EventStorage.storeEvents(tempList);
            }
        }

        private static void sendEvent(Event e)
        {
            Utils.log("sendEvent(" + e.name + ")");

            eventSender = new EventSender(e);
            eventSender.OnEventSent += new EventHandler<EventSender.EventSenderArgs>(onEventSent);
            eventSender.OnEventFailed += new EventHandler<EventSender.EventSenderArgs>(onEventFailed);
            eventSender.start();
        }

        private static void sendNextEvent()
        {
            if (eventsList.Count > 0)
            {
                Utils.log("sendNextEvent(): " + eventsList[0].name);
                sendEvent(eventsList[0]);
            }
            else
            {
                Utils.log("sendNextEvent(): No more events to send");
            }
        }

        // Callback methods

        internal static void onEventSent(object sender, EventSender.EventSenderArgs e)
        {
            Utils.log("onEventSent(): " + e.theEvent.name);

            eventSender = null;

            removeEvent(e.theEvent);

            sendNextEvent();
        }

        internal static void onEventFailed(object sender, EventSender.EventSenderArgs e)
        {
            Utils.log("onEventFailed(): " + e.theEvent.name);

            eventSender = null;

            sendNextEvent();
        }

        /****************
         * EVENTFACTORY *
         ****************/

        internal class EventFactory
        {
            private EventFactory() { }

            internal static Event createEvent(String name, Dictionary<String, String> parameters, String postData)
            {
                return EventFactory.createEvent(name, parameters, postData, false, false);
            }

            internal static Event createEvent(String name, Dictionary<String, String> parameters, String postData, Boolean generateHash, Boolean requiresCookie)
            {
                return new Event(name, parameters, postData, generateHash, requiresCookie, Utils.currentTimeMillis(), SDK.bundleID, SDK.appVersion, SDK.SDK_VERSION, SDK.publicKey, SDK.privateKey, SDK.uniqueUserID, SDK.uniqueHardwareID);
            }
        }

        /***************
         * EVENTSENDER *
         ***************/

        internal class EventSender
        {
            internal class EventSenderArgs : EventArgs
            {
                internal Event theEvent;

                internal EventSenderArgs(Event e)
                {
                    this.theEvent = e;
                }
            }

            internal EventHandler<EventSenderArgs> OnEventSent;
            internal EventHandler<EventSenderArgs> OnEventFailed;

            private static readonly String USER_AGENT = "DistimoSDK/" + SDK.SDK_VERSION;
            private static readonly String EVENT_URL = "https://a.distimo.mobi/e/?";
 
            //Generic variables
            private Event currentEvent;
            private Boolean isStarted;
            private Boolean isCanceled;

            //WebBrowser variables
            private WebBrowser webBrowser;

            //HttpWebRequest variables
            private HttpWebRequest webRequest;
            private BackgroundWorker webRequestWorker;
            private AutoResetEvent autoResetEvent;
            private Boolean eventSent;

            // Constructors

            private EventSender() { }

            internal EventSender(Event e)
            {
                this.currentEvent = e;
            }

            // Internal methods

            internal void start()
            {
                if (!this.isStarted)
                {
                    this.isStarted = true;

                    String eventURL = EVENT_URL + this.currentEvent.urlParamString(SDK.publicKey, SDK.uniqueUserID, SDK.uniqueHardwareID);

                    if (this.currentEvent.generateHash || this.currentEvent.requiresCookie)
                    {
                        this.sendEventWithWebBrowser(eventURL);
                    }
                    else
                    {
                        this.sendEventWithHttpRequest(eventURL);
                    }
                }
            }

            internal void cancel()
            {
                this.isCanceled = true;

                if (this.webRequestWorker != null && this.webRequestWorker.WorkerSupportsCancellation)
                {
                    this.webRequest.Abort();
                    this.webRequestWorker.CancelAsync();
                }
                else
                {
                    cleanup();
                }
            }

            // Private methods

            private void cleanup()
            {
                this.currentEvent = null;
                this.webBrowser = null;
                this.webRequestWorker = null;
                this.autoResetEvent = null;
                this.OnEventFailed = null;
                this.OnEventSent = null;
            }

            // HttpWebRequest methods

            private void sendEventWithHttpRequest(String eventURL)
            {
                webRequestWorker = new BackgroundWorker();
                webRequestWorker.WorkerReportsProgress = false;
                webRequestWorker.WorkerSupportsCancellation = true;
                webRequestWorker.DoWork += new DoWorkEventHandler(webRequestWorker_DoWork);
                webRequestWorker.RunWorkerCompleted += new RunWorkerCompletedEventHandler(webRequestWorker_RunWorkerCompleted);
                webRequestWorker.RunWorkerAsync(eventURL);
            }
            private void webRequestWorker_DoWork(object sender, DoWorkEventArgs e)
            {
                try
                {
                    BackgroundWorker worker = sender as BackgroundWorker;

                    String eventURL = (String)e.Argument;

                    Utils.log("Calling " + eventURL);

                    webRequest = (HttpWebRequest)HttpWebRequest.Create(new Uri(eventURL));
                    webRequest.UserAgent = USER_AGENT;

                    if (this.currentEvent.postData != null && this.currentEvent.postData.Length > 0)
                    {
                        webRequest.Method = "POST";
                        webRequest.BeginGetRequestStream(new AsyncCallback(webRequest_Write_Callback), webRequest);
                    }
                    else
                    {
                        webRequest.Method = "GET";
                        webRequest.BeginGetResponse(new AsyncCallback(webRequest_Read_Callback), webRequest);
                    }

                    //Wait for the response to be finished
                    autoResetEvent = new AutoResetEvent(false);
                    autoResetEvent.WaitOne();
                }
                catch (Exception exc)
                {
                    Utils.log(exc.StackTrace);
                }
            }
            private void webRequestWorker_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
            {
                if (eventSent)
                {
                    if (this.OnEventSent != null)
                    {
                        OnEventSent(this, new EventSenderArgs(this.currentEvent));
                    }
                }
                else
                {
                    if (this.OnEventFailed != null)
                    {
                        OnEventFailed(this, new EventSenderArgs(this.currentEvent));
                    }
                }

                cleanup();
            }

            private void webRequest_Write_Callback(IAsyncResult asyncResult)
            {
                if (this.currentEvent != null)
                {
                    HttpWebRequest webRequest = (HttpWebRequest)asyncResult.AsyncState;

                    try
                    {
                        Stream requestStream = webRequest.EndGetRequestStream(asyncResult);
                        StreamWriter streamWriter = new StreamWriter(requestStream);
                        streamWriter.Write(this.currentEvent.postData);
                        streamWriter.Close();

                        webRequest.BeginGetResponse(new AsyncCallback(webRequest_Read_Callback), webRequest);
                    }
                    catch (Exception e)
                    {
                        Utils.log(e.StackTrace);

                        autoResetEvent.Set();
                    }
                }
            }

            private void webRequest_Read_Callback(IAsyncResult asyncResult)
            {
                if (this.currentEvent != null)
                {
                    HttpWebRequest webRequest = (HttpWebRequest)asyncResult.AsyncState;
                    try
                    {
                        HttpWebResponse webResponse = (HttpWebResponse)webRequest.EndGetResponse(asyncResult);

                        Utils.log(this.currentEvent.name + ": " + webResponse.StatusCode.ToString());

                        if (webResponse.StatusCode == HttpStatusCode.OK)
                        {
                            eventSent = true;
                        }
                    }
                    catch (Exception e)
                    {
                        Utils.log(e.StackTrace);
                    }
                }

                autoResetEvent.Set();
            }

            // WebBrowser methods

            private void sendEventWithWebBrowser(String eventURL)
            {
                Utils.log("Calling " + eventURL);

                try
                {
                    this.webBrowser = new WebBrowser();
                }
                catch (Exception)
                {
                    //Failing because WebBrowser creation failed
                    if (this.OnEventFailed != null)
                    {
                        OnEventFailed(this, new EventSenderArgs(this.currentEvent));
                    }
                    return;
                }

                this.webBrowser.Opacity = 0.0;
                this.webBrowser.Width = System.Windows.Application.Current.Host.Content.ActualWidth;
                this.webBrowser.Height = System.Windows.Application.Current.Host.Content.ActualHeight;
                this.webBrowser.IsScriptEnabled = true;

                this.webBrowser.Navigating += new EventHandler<NavigatingEventArgs>(webBrowser_Navigating);
                this.webBrowser.Navigated += new EventHandler<System.Windows.Navigation.NavigationEventArgs>(webBrowser_Navigated);
                this.webBrowser.LoadCompleted += new System.Windows.Navigation.LoadCompletedEventHandler(webBrowser_LoadCompleted);
                this.webBrowser.NavigationFailed += new System.Windows.Navigation.NavigationFailedEventHandler(webBrowser_NavigationFailed);

                //POST in webbrowser is not supported because of redirect

                this.webBrowser.Navigate(new Uri(eventURL));
            }

            void webBrowser_Navigating(object sender, NavigatingEventArgs e)
            {
                if (this.currentEvent != null)
                {
                    Utils.log(this.currentEvent.name + ": Navigating (" + e.Uri.ToString() + ")");
                }

                if (this.isCanceled == true || e.Uri.ToString().StartsWith("done://"))
                {
                    //When the request starts with "done://", don't continue from here because it will trigger a popup (LoadCompleted will get called)

                    Utils.log("Navigating: Canceling!");
                    e.Cancel = true;
                }
            }

            void webBrowser_Navigated(object sender, System.Windows.Navigation.NavigationEventArgs e)
            {
                if (this.currentEvent != null)
                {
                    Utils.log(this.currentEvent.name + ": Navigated (" + e.Uri.ToString() + ")");
                }
            }

            void webBrowser_LoadCompleted(object sender, System.Windows.Navigation.NavigationEventArgs e)
            {
                if (this.currentEvent != null)
                {
                    Utils.log(this.currentEvent.name + ": LoadCompleted (" + e.Uri.ToString() + ")");

                    if (this.OnEventSent != null)
                    {
                        OnEventSent(this, new EventSenderArgs(this.currentEvent));
                    }
                }

                cleanup();
            }

            void webBrowser_NavigationFailed(object sender, System.Windows.Navigation.NavigationFailedEventArgs e)
            {
                if (this.currentEvent != null)
                {
                    Utils.log(this.currentEvent.name + ": NavigationFailed (" + e.Uri.ToString() + ")");

                    if (this.OnEventFailed != null)
                    {
                        OnEventFailed(this, new EventSenderArgs(this.currentEvent));
                    }
                }

                cleanup();
            }
        }

        /****************
         * EVENTSTORAGE *
         ****************/

        private class EventStorage
        {
            private static readonly String FILE_NAME = "MqUYZVWxWzATu57WcrRC";

            private EventStorage() { }

            internal static void storeEvents(List<Event> events)
            {
                Utils.log("storeEvents(" + events.Count + ")");

                if (events.Count > 0)
                {
                    //Create string with lines representing events
                    StringBuilder sb = new StringBuilder();

                    foreach (Event e in events)
                    {
                        //Protobuf serialize
                        MemoryStream stream = new MemoryStream();
                        Distimo.EventSerializer serializer = new Distimo.EventSerializer();
                        serializer.Serialize(stream, e);
                        byte[] eventData = stream.ToArray();

                        //Base64 encode
                        String base64EncodedContent = Convert.ToBase64String(eventData);

                        //Add line to result
                        sb.AppendLine(base64EncodedContent);
                    }

                    //Write complete string
                    StorageManager.store(sb.ToString(), FILE_NAME);
                }
            }

            internal static List<Event> getEvents()
            {
                Utils.log("getEvents()");

                List<Event> result = new List<Event>();

                //Read all event lines from storage (and delete the file)
                String allEvents = StorageManager.read(FILE_NAME, true);

                if (allEvents != null)
                {
                    //Split event lines
                    String[] allEventsLines = allEvents.Split(Environment.NewLine.ToCharArray(), StringSplitOptions.RemoveEmptyEntries);

                    foreach (String eventStr in allEventsLines)
                    {
                        //Base64 decode
                        byte[] eventData = Convert.FromBase64String(eventStr);

                        //Protobuf deserialize
                        MemoryStream stream = new MemoryStream(eventData);
                        Event e = new Event();
                        Type type = e.GetType();
                        EventSerializer serializer = new EventSerializer();
                        serializer.Deserialize(stream, e, type);

                        //Recalculate checksum
                        e.calculateChecksum(SDK.publicKey, SDK.privateKey, SDK.uniqueUserID, SDK.uniqueHardwareID);

                        //Set new ID
                        e.setNewID();

                        Utils.log("Restored " + e.name + "  event with (new) ID " + e._id);

                        //Add to result set
                        result.Add(e);
                    }
                }
                else
                {
                    Utils.log("No stored events found");
                }

                return result;
            }
        }
    }
}
