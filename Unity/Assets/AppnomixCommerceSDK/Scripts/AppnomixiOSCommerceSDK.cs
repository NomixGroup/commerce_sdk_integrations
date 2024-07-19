using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixCommerce
{
    public class AppnomixiOSCommerceSDK : IAppnomixCommerceSDK
    {
        [DllImport ("__Internal")]
        private static extern void AppnomixCommerceSDK_start(
            string clientID,
            string authToken,
            string appGroupName,
            string onboardingLogoAssetName,
            string appURLScheme,
            bool requestLocation,
            bool requestTracking);

        [DllImport ("__Internal")]
        private static extern void AppnomixCommerceSDK_showOnboarding ();

        [DllImport ("__Internal")]
        private static extern bool AppnomixCommerceSDK_isExtensionInstalled();

        public void InitSdk(
            string clientID, 
            string authToken,
            string appGroupName_iOS, // e.g. group.app.appnomix.demo-unity
            string onboardingLogoAssetName, 
            string appURLScheme_iOS, // e.g. savers-league-coupons://
            bool requestLocation, 
            bool requestTracking)
        {
            try
            {
                AppnomixCommerceSDK_start(
                    clientID,
                    authToken,
                    appGroupName_iOS,
                    onboardingLogoAssetName,
                    appURLScheme_iOS,
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
                if (!AppnomixCommerceSDK_isExtensionInstalled()) {
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
