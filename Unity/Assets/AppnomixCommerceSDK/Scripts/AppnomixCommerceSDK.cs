using UnityEngine;

namespace AppnomixCommerce
{
    public interface IAppnomixCommerceSDK
    {
        void InitSdk(
            string clientID, 
            string authToken, 
            string appGroupName_iOS, // e.g. group.app.appnomix.demo-unity
            string onboardingLogoAssetName, 
            string appURLScheme_iOS, // e.g. savers-league-coupons://
            bool requestLocation, 
            bool requestTracking);

        void LaunchOnboarding();
    }

    public class AppnomixCommerceSDK
    {
        private IAppnomixCommerceSDK appnomixSDK;

        public AppnomixCommerceSDK()
        {
            #if UNITY_IOS
                appnomixSDK = new AppnomixiOSCommerceSDK();
            #elif UNITY_ANDROID
                appnomixSDK = new AppnomixiOSCommerceSDK();
            #else
                Debug.LogError("Unsupported platform");
            #endif
        }

        public void LaunchSDK(
            string clientID, 
            string authToken,
            string appGroupName_iOS, // e.g. group.app.appnomix.demo-unity
            string onboardingLogoAssetName, 
            string appURLScheme_iOS, // e.g. savers-league-coupons://
            bool requestLocation, 
            bool requestTracking)
        {
            appnomixSDK?.InitSdk(
                clientID,
                authToken,
                appGroupName_iOS,
                onboardingLogoAssetName,
                appURLScheme_iOS,
                requestLocation,
                requestTracking);

            appnomixSDK?.LaunchOnboarding();
        }
    }
}
