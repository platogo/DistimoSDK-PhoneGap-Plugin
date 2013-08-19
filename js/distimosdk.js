(function() {
	var cordova = window.cordova || window.Cordova;
	var service = 'DistimoSDK';
	
	var DistimoSDK = {
	
		/**
		 * Start the Distimo SDK
		 * 
		 * @param sdkKey Your Distimo SDK Key, go to https://analytics.distimo.com/settings/sdk to generate an SDK Key.
		 **/
		start: function(sdkKey) {
			var success = function() { console.log('Distimo SDK started successfully.'); };
			var failure = function(err) { console.log('Distimo SDK failed to start: ' + err ); };
			var action = 'start';
			var args = [sdkKey];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		//Settings
		
		/**
		 * Get the version of the native Distimo SDK
		 * 
		 * @return The version of the Distimo SDK
		 */
		version: function(callback) {
			var success = function(version) { console.log('Success: version (' + version + ')'); callback(version); };
			var failure = function(err) { console.log('Error retrieving version: ' + err); };
			var action = 'version';
			var args = [];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		//User Value
	
		/**
		 * Mark this user as newly registered
		 **/
		logUserRegistered: function() {
			var success = function() { console.log('Success: logUserRegistered'); };
			var failure = function(err) { console.log('Error on logUserRegistered: ' + err); };
			var action = 'logUserRegistered';
			var args = [];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * iOS ONLY
		 * 
		 * Log an in-app purchase that this user completed, specified with a locale
		 * 
		 * @param productID The ID the in-app product
		 * @param locale The locale for the currency used for this purchase
		 * @param price The price of the product
		 * @param quantity Number of purchased products
		 */
		logInAppPurchaseWithLocale: function(productID, locale, price, quantity) {
			var success = function() { console.log('Success: logInAppPurchaseWithLocale'); };
			var failure = function(err) { console.log('Error on logInAppPurchaseWithLocale: ' + err); };
			var action = 'logInAppPurchaseWithLocale';
			var args = [productID, locale, price, quantity];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * iOS ONLY
		 * 
		 * Log an in-app purchase that this user completed, specified with an ISO 4217 international currency symbol
		 * 
		 * @param productID The ID of the in-app product
		 * @param currencyCode The ISO 4217 currency code for the currency used for this purchase
		 * @param price The price of the product
		 * @param quantity Number of purchased products
		 */
		logInAppPurchaseWithCurrency: function(productID, currencyCode, price, quantity) {
			var success = function() { console.log('Success: logInAppPurchaseWithCurrency'); };
			var failure = function(err) { console.log('Error on logInAppPurchaseWithCurrency: ' + err); };
			var action = 'logInAppPurchaseWithCurrency';
			var args = [productID, currencyCode, price, quantity];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * Android ONLY
		 * 
		 * Log an in-app purchase that this user completed
		 * 
		 * @param productID The ID of the in-app product
		 * @param orderID The merchant order ID
		 */
		logInAppPurchase: function(productID, orderID) {
			var success = function() { console.log('Success: logInAppPurchase'); };
			var failure = function(err) { console.log('Error on logInAppPurchase: ' + err); };
			var action = 'logInAppPurchase';
			var args = [productID, orderID];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * Windows Phone ONLY
		 * 
		 * Log an in-app product specified with a formatted price
		 * 
		 * @param productID The ID of the in-app product
		 * @param orderID The merchant order ID
		 */
		logInAppPurchaseWithFormattedPrice: function(productID, formattedPrice) {
			var success = function() { console.log('Success: logInAppPurchaseWithFormattedPrice'); };
			var failure = function(err) { console.log('Error on logInAppPurchaseWithFormattedPrice: ' + err); };
			var action = 'logInAppPurchaseWithFormattedPrice';
			var args = [productID, formattedPrice];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * Android ONLY
		 * 
		 * Log in-app product that was refunded for this user
		 * 
		 * @param productID The ID of the in-app product
		 * @param orderID The merchant order ID
		 */
		logInAppPurchaseRefunded: function(productID, orderID) {
			var success = function() { console.log('Success: logInAppPurchaseRefunded'); };
			var failure = function(err) { console.log('Error on logInAppPurchaseRefunded: ' + err); };
			var action = 'logInAppPurchaseRefunded';
			var args = [productID, orderID];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * iOS ONLY
		 * 
		 * Log an external purchase that this user completed, e.g. consumer goods or a booking,
		 *  specified with a locale
		 * 
		 * @param productID The productID of the external purchase
		 * @param locale The locale for the currency used for this purchase
		 * @param price The price of the product
		 * @param quantity Number of purchased products
		 */
		logExternalPurchaseWithLocale: function(productID, locale, price, quantity) {
			var success = function() { console.log('Success: logExternalPurchaseWithLocale'); };
			var failure = function(err) { console.log('Error on logExternalPurchaseWithLocale: ' + err); };
			var action = 'logExternalPurchaseWithLocale';
			var args = [productID, locale, price, quantity];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * Log an external purchase that this user completed, e.g. consumer goods or a booking,
		 *  specified with an ISO 4217 international currency symbol
		 * 
		 * @param productID The productID of the external purchase
		 * @param currencyCode The ISO 4217 currency code for the currency used for this purchase
		 * @param price The price of the product
		 * @param quantity Number of purchased products
		 */
		logExternalPurchaseWithCurrency: function(productID, currencyCode, price, quantity) {
			var success = function() { console.log('Success: logExternalPurchaseWithCurrency'); };
			var failure = function(err) { console.log('Error on logExternalPurchaseWithCurrency: ' + err); };
			var action = 'logExternalPurchaseWithCurrency';
			var args = [productID, currencyCode, price, quantity];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		/**
		 * Log a banner click
		 *
		 * @param publisher The publisher of the banner (optional)
		 **/
		logBannerClick: function(publisher) {
			var success = function() { console.log('Success: logBannerClick'); };
			var failure = function(err) { console.log('Error on logBannerClick: ' + err); };
			var action = 'logBannerClick';
			var args = [publisher];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		//User Properties
	
		/**
		 * Set a self-defined userID for this user. This userID is used to provide you with detailed
		 *  source information that this user originated from.
		 * 
		 * @param userID Your self-defined userID of this user
		 */
		setUserID: function(userID) {
			var success = function() { console.log('Success: setUserID'); };
			var failure = function(err) { console.log('Error on setUserID: ' + err); };
			var action = 'setUserID';
			var args = [userID];
		
			cordova.exec(success, failure, service, action, args);
		},
	
		//AppLink
	
		/**
		 * Redirects directly to the AppStore by routing through your AppLink. Use this for tracking
		 *  conversion from within your own apps, e.g. for upselling to your Pro apps.
		 *
		 * Note: The redirect will happen in the background, this can take a couple of seconds.
		 *
		 * @param applinkHandle The handle of the AppLink you want to open, e.g. @"A00"
		 * @param campaignHandle The handle of the campaign you want to use, e.g. @"a" (optional)
		 **/
		openAppLink: function(applinkHandle, campaignHandle) {
			var success = function() { console.log('Success: openAppLink'); };
			var failure = function(err) { console.log('Error on openAppLink: ' + err); };
			var action = 'openAppLink';
			var args = [applinkHandle, campaignHandle];
		
			cordova.exec(success, failure, service, action, args);
		}
	
	}
	
	window.DistimoSDK = DistimoSDK;
})();