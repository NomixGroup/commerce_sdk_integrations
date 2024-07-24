#if UNITY_IOS

using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixCommerce
{
    public class AppnomixiOSCommerceSDK : IAppnomixCommerceSDK
    {
        private readonly string appGroupName;
        private readonly string appURLScheme;
        private readonly bool requestLocation;
        private readonly bool requestTracking;

        public AppnomixiOSCommerceSDK(
            string appGroupName,
            string appURLScheme,
            bool requestLocation,
            bool requestTracking
        )
        {
            this.appGroupName = appGroupName;
            this.appURLScheme = appURLScheme;
            this.requestLocation = requestLocation;
            this.requestTracking = requestTracking;
        }

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
        private static extern void AppnomixCommerceSDK_showOnboarding();

        [DllImport("__Internal")]
        private static extern bool AppnomixCommerceSDK_isExtensionInstalled();

        public void InitSdk(
            string clientID,
            string authToken)
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

        public void LaunchOnboarding()
        {
            Debug.Log("LaunchOnboarding");
            try
            {
                if (!AppnomixCommerceSDK_isExtensionInstalled())
                {
                    AppnomixCommerceSDK_showOnboarding();
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to show onboarding: " + e.Message);
            }
        }
    }
}

#endif
