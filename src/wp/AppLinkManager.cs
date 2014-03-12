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
using Microsoft.Phone.Tasks;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Distimo
{
    internal sealed class AppLinkManager
    {
        private static AppLinkRedirector currentRedirector;

        internal static void openAppLink(String applinkHandle, String campaignHandle, String uniqueID)
        {
            if (currentRedirector != null)
            {
                currentRedirector.cancel();
                currentRedirector = null;
            }

            if (applinkHandle != null && applinkHandle.Length > 0)
            {
                StringBuilder builder = new StringBuilder("http://app.lk/").Append(applinkHandle).Append("/redirect?x=");
                if (campaignHandle != null)
                {
                    builder.Append(campaignHandle);
                }
                builder.Append("&u=");
                if (uniqueID != null)
                {
                    builder.Append(uniqueID);
                }

                //Call url
                currentRedirector = new AppLinkRedirector(builder.ToString());
                currentRedirector.OnRedirectDone += new EventHandler<AppLinkRedirector.AppLinkRedirectorArgs>(OnRedirectDone);
                currentRedirector.OnRedirectFailed += new EventHandler<AppLinkRedirector.AppLinkRedirectorArgs>(OnRedirectFailed);
                currentRedirector.start();
            }
        }

        //Callback methods

        internal static void OnRedirectDone(object sender, AppLinkRedirector.AppLinkRedirectorArgs e)
        {
            if (sender.Equals(currentRedirector))
            {
                Utils.log("OnRedirectDone");

                currentRedirector = null;
            }
        }

        internal static void OnRedirectFailed(object sender, AppLinkRedirector.AppLinkRedirectorArgs e)
        {
            if (sender.Equals(currentRedirector))
            {
                if (e.fallbackUrl != null)
                {
                    Utils.log("OnRedirectFailed fallbackUrl: " + e.fallbackUrl);

                    WebBrowserTask task = new WebBrowserTask();
                    task.Uri = new Uri(e.fallbackUrl);
                    try
                    {
                        task.Show();
                    }
                    catch (Exception)
                    {
                        //Just don't show the task
                    }
                }

                currentRedirector = null;
            }
        }

        /*********************
         * APPLINKREDIRECTOR *
         ********************/

        internal class AppLinkRedirector
        {
            //Callbacks

            internal class AppLinkRedirectorArgs : EventArgs
            {
                internal String fallbackUrl;

                internal AppLinkRedirectorArgs(String fallbackUrl)
                {
                    this.fallbackUrl = fallbackUrl;
                }
            }

            internal EventHandler<AppLinkRedirectorArgs> OnRedirectDone;
            internal EventHandler<AppLinkRedirectorArgs> OnRedirectFailed;

            //Variables

            private String applinkUrl;

            private Boolean isStarted;
            private Boolean isCanceled;
            private Boolean success;

            private WebBrowser webBrowser;

            // Constructors

            private AppLinkRedirector() { }

            internal AppLinkRedirector(String url)
            {
                this.applinkUrl = url;
            }

            // Internal methods

            internal void start()
            {
                if (!this.isStarted && this.applinkUrl != null)
                {
                    this.isStarted = true;

                    this.openAppLinkWithWebBrowser(this.applinkUrl);
                }
            }

            internal void cancel()
            {
                Utils.log("AppLinkRedirector Canceling...");

                this.isCanceled = true;

                cleanup();
            }

            // Private methods

            private void finished()
            {
                //Trigger callback
                if (this.success == true && this.OnRedirectDone != null)
                {
                    this.OnRedirectDone(this, null);
                }
                else if (this.success == false && this.OnRedirectFailed != null)
                {
                    this.OnRedirectFailed(this, new AppLinkRedirectorArgs(this.applinkUrl));
                }

                //Cleanup
                cleanup();

            }

            private void cleanup()
            {
                this.OnRedirectDone = null;
                this.OnRedirectFailed = null;
                this.applinkUrl = null;
                this.webBrowser = null;
            }

            // WebBrowser methods

            private void openAppLinkWithWebBrowser(String url)
            {
                Utils.log("Calling " + url);
                
                this.webBrowser = new WebBrowser();
                this.webBrowser.Opacity = 0.0;
                this.webBrowser.Width = System.Windows.Application.Current.Host.Content.ActualWidth;
                this.webBrowser.Height = System.Windows.Application.Current.Host.Content.ActualHeight;
                this.webBrowser.IsScriptEnabled = true;

                this.webBrowser.Navigating += new EventHandler<NavigatingEventArgs>(webBrowser_Navigating);
                this.webBrowser.Navigated += new EventHandler<System.Windows.Navigation.NavigationEventArgs>(webBrowser_Navigated);
                this.webBrowser.LoadCompleted += new System.Windows.Navigation.LoadCompletedEventHandler(webBrowser_LoadCompleted);
                this.webBrowser.NavigationFailed += new System.Windows.Navigation.NavigationFailedEventHandler(webBrowser_NavigationFailed);

                this.webBrowser.Navigate(new Uri(url));
            }

            private void webBrowser_Navigating(object sender, NavigatingEventArgs e)
            {
                String logString = (e != null && e.Uri != null ? e.Uri.ToString() : "");
                Utils.log("AppLinkRedirector Navigating (" + logString + ")");

                if (this.isCanceled == true)
                {
                    Utils.log("AppLinkRedirector Navigating: Canceling!");

                    //Cancel the navigation
                    e.Cancel = true;
                }
                else if (e.Uri != null && !e.Uri.ToString().StartsWith("http://") && !e.Uri.ToString().StartsWith("https://"))
                {
                    Utils.log("AppLinkRedirector Navigating: Found store URL!");

                    //The WebBrowser will open the store, continue...
                    this.success = true;
                }
            }

            private void webBrowser_Navigated(object sender, System.Windows.Navigation.NavigationEventArgs e)
            {
                String logString = (e != null && e.Uri != null ? e.Uri.ToString() : "");
                Utils.log("AppLinkRedirector Navigated (" + logString + ")");
            }

            private void webBrowser_LoadCompleted(object sender, System.Windows.Navigation.NavigationEventArgs e)
            {
                String logString = (e != null && e.Uri != null ? e.Uri.ToString() : "");
                Utils.log("AppLinkRedirector LoadCompleted (" + logString + ")");

                this.finished();
            }

            private void webBrowser_NavigationFailed(object sender, System.Windows.Navigation.NavigationFailedEventArgs e)
            {
                String logString = (e != null && e.Uri != null ? e.Uri.ToString() : "");
                Utils.log("AppLinkRedirector NavigationFailed (" + logString + ")");

                this.finished();
            }
        }
    }
}
