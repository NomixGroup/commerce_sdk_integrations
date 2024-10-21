#if UNITY_IOS

using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixCommerce
{
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
            bool requestTracking);

        [DllImport("__Internal")]
        private static extern void AppnomixCommerceSDK_showOnboarding(OnboardingEventCallback callback = null);

        [DllImport("__Internal")]
        private static extern bool AppnomixCommerceSDK_isExtensionInstalled();

        private readonly string clientID;
        private readonly string authToken;
        private readonly string appGroupName;
        private readonly string appURLScheme;
        private readonly bool requestLocation;
        private readonly bool requestTracking;

        public AppnomixiOSCommerceSDK(
            string clientID,
            string authToken,
            string appGroupName,
            string appURLScheme,
            bool requestLocation,
            bool requestTracking
        )
        {
            this.clientID = clientID;
            this.authToken = authToken;
            this.appGroupName = appGroupName;
            this.appURLScheme = appURLScheme;
            this.requestLocation = requestLocation;
            this.requestTracking = requestTracking;

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
                    requestTracking);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to call SDK initializer: " + e.Message);
            }
        }

        public void LaunchOnboarding(OnboardingEventCallback callback = null)
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
    }
}

#endif
