using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixCommerceSDK.Scripts
{ 
#if UNITY_IOS
    public class AppnomixiOSCommerceSDK : IAppnomixCommerceSDK
    {
        [DllImport("__Internal")]
        private static extern void AppnomixCSDK_start(
            string clientID,
            string authToken,
            string appGroupName,
            string appURLScheme,
            string language);

        [DllImport("__Internal")]
        private static extern void AppnomixCSDK_showOnboarding(AnalyticsEventCallback callback = null);

        [DllImport("__Internal")]
        private static extern bool AppnomixCSDK_isExtensionInstalled();

        [DllImport("__Internal")]
        private static extern bool AppnomixCSDK_isOnboardingAvailable();

        [DllImport("__Internal")]
        private static extern void AppnomixCSDK_trackOfferDisplay(string context);

        private readonly string clientID;
        private readonly string authToken;
        private readonly string appGroupName;
        private readonly string appURLScheme;
        private readonly string language;

        public AppnomixiOSCommerceSDK(
            string clientID,
            string authToken,
            string appGroupName,
            string appURLScheme,
            string language
        )
        {
            this.clientID = clientID;
            this.authToken = authToken;
            this.appGroupName = appGroupName;
            this.appURLScheme = appURLScheme;
            this.language = language;

            InitSdk();
        }

        private void InitSdk()
        {
            try
            {
                AppnomixCSDK_start(
                    clientID,
                    authToken,
                    appGroupName,
                    appURLScheme,
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
                    AppnomixCSDK_showOnboarding(callback);
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to show onboarding: " + e.Message);
            }
        }

        public bool IsOnboardingDone()
        {
            return AppnomixCSDK_isExtensionInstalled();
        }

        public bool IsOnboardingAvailable()
        {
            return AppnomixCSDK_isOnboardingAvailable();
        }

        public void TrackOfferDisplay(string context)
        {
            AppnomixCSDK_trackOfferDisplay(context);
        }    
    }
#endif
}
