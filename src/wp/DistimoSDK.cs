using System;
using System.Windows;

using WPCordovaClassLib.Cordova;
using WPCordovaClassLib.Cordova.Commands;
using WPCordovaClassLib.Cordova.JSON;

namespace WPCordovaClassLib.Cordova.Commands
{
    public class DistimoSDK : BaseCommand
    {

        // Start

        public void start(string options)
        {
            string[] args = this.getArgs(options);

            if (args != null && args.Length >= 1)
            {
                string sdkKey = args[0];

                Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.start(sdkKey); });
                DispatchCommandResult();
            }
            else
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Please provide a valid SDK Key, you can create one at https://analytics.distimo.com/settings/sdk."));
            }
        }

        // Settings

        public void version(string options)
        {
            string version = Distimo.SDK.version();

            if (version != null)
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.OK, version));
            }
            else
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Could not retrieve DistimoSDK version"));
            }
        }

        // User Value

        public void logUserRegistered(string options)
        {
            Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.logUserRegistered(); });
            DispatchCommandResult();
        }

        public void logInAppPurchaseWithFormattedPrice(string options)
        {
            string[] args = this.getArgs(options);

            if (args != null && args.Length >= 2)
            {
                string productID = args[0];
                string formattedPrice = args[1];

                Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.logInAppPurchase(productID, formattedPrice); });
                DispatchCommandResult();
            }
            else
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Not enough arguments provided"));
            }
        }

        public void logExternalPurchaseWithCurrency(string options)
        {
            string[] args = this.getArgs(options);

            if (args != null && args.Length >= 4)
            {
                string productID = args[0];
                string currency = args[1];
                string price = args[2];
                string quantity = args[3];

                try
                {
                    Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.logExternalPurchase(productID, currency, double.Parse(price), int.Parse(quantity)); });
                    DispatchCommandResult();
                }
                catch (Exception e)
                {
                    DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Please provide a valid price and/or quantity"));
                }
            }
            else
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Not enough arguments provided"));
            }
        }

        public void logBannerClick(string options)
        {
            string[] args = this.getArgs(options);

            string publisher = (args != null && args.Length >= 1 ? args[0] : null);

            Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.logBannerClick(publisher); });
            DispatchCommandResult();
        }

        // User Properties

        public void setUserID(string options)
        {
            string[] args = this.getArgs(options);

            string userID = (args != null && args.Length >= 1 ? args[0] : null);

            Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.setUserID(userID); });
            DispatchCommandResult();
        }

        // AppLink

        public void openAppLink(string options)
        {
            string[] args = this.getArgs(options);

            if (args != null && args.Length >= 1)
            {
                string applinkHandle = args[0];
                string campaignHandle = (args.Length >= 2 ? args[1] : null);

                Deployment.Current.Dispatcher.BeginInvoke(() => { Distimo.SDK.openAppLink(applinkHandle, campaignHandle); });
                DispatchCommandResult();
            }
            else
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, "Not enough arguments provided"));
            }
        }

        private string[] getArgs(string options)
        {
            try
            {
                string[] args = JsonHelper.Deserialize<string[]>(options);
                return args;
            }
            catch (Exception e)
            {
                Console.Write(e.StackTrace);
            }

            return null;
        }
    }
}
