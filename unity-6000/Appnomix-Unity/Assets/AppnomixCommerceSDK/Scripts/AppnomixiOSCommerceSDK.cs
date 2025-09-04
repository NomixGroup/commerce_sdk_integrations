using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixCommerceSDK.Scripts
{ 
#if UNITY_IOS
    public class AppnomixiOSCommerceSDK : IAppnomixCommerceSDK
    {
        [DllImport("__Internal")]
        private static extern void AppnomixCommerceSDK_start(
            string clientID,
            string authToken,
            string appGroupName,
            string onboardingLogoAssetName,
            string appURLScheme,
            bool requestLocation,
            bool requestTracking,
            string language);

        [DllImport("__Internal")]
        private static extern void AppnomixCommerceSDK_showOnboarding(AnalyticsEventCallback callback = null);

        [DllImport("__Internal")]
        private static extern bool AppnomixCommerceSDK_isExtensionInstalled();

        [DllImport("__Internal")]
        private static extern void AppnomixCommerceSDK_trackOfferDisplay(string context);

        private readonly string clientID;
        private readonly string authToken;
        private readonly string appGroupName;
        private readonly string appURLScheme;
        private readonly bool requestLocation;
        private readonly bool requestTracking;
        private readonly string language;

        public AppnomixiOSCommerceSDK(
            string clientID,
            string authToken,
            string appGroupName,
            string appURLScheme,
            bool requestLocation,
            bool requestTracking,
            string language
        )
        {
            this.clientID = clientID;
            this.authToken = authToken;
            this.appGroupName = appGroupName;
            this.appURLScheme = appURLScheme;
            this.requestLocation = requestLocation;
            this.requestTracking = requestTracking;
            this.language = language;

            InitSdk();
        }

        private void InitSdk()
        {
            try
            {
                AppnomixCommerceSDK_start(
                    clientID,
                    authToken,
                    appGroupName,
                    "",
                    appURLScheme,
                    requestLocation,
                    requestTracking,
                    language);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to call SDK initializer: " + e.Message);
            }
        }

        public void LaunchOnboarding(AnalyticsEventCallback callback = null)
        {
            try
            {
                if (!IsOnboardingDone())
                {
                    AppnomixCommerceSDK_showOnboarding(callback);
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to show onboarding: " + e.Message);
            }
        }

        public bool IsOnboardingDone()
        {
            return AppnomixCommerceSDK_isExtensionInstalled();
        }

        public bool IsOnboardingAvailable()
        {
            // TODO
            return false;
        }

        public void TrackOfferDisplay(string context)
        {
            AppnomixCommerceSDK_trackOfferDisplay(context);
        }    
    }
#endif
}
