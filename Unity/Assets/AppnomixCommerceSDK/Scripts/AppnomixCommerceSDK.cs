using UnityEngine;

namespace AppnomixCommerce
{
    public interface IAppnomixCommerceSDK
    {
        void InitSdk(
            string clientID,
            string authToken);

        void LaunchOnboarding();
    }

    public class AppnomixCommerceSDK
    {
        private readonly IAppnomixCommerceSDK sdkWrapper;

        public AppnomixCommerceSDK(
            string iOSAppGroupName, // e.g. group.app.appnomix.demo-unity
            string iOSAppURLScheme, // e.g. savers-league-coupons://
            string onboardingLogoAssetName,
            bool requestLocation,
            bool requestTracking)
        {
#if UNITY_IOS
            sdkWrapper = new AppnomixiOSCommerceSDK(
                            iOSAppGroupName,
                            onboardingLogoAssetName,
                            iOSAppURLScheme,
                            requestLocation,
                            requestTracking
                        );
#elif UNITY_ANDROID
            sdkWrapper = new AppnomixAndroidCommerceSDK();
#else
            Debug.LogError("Unsupported platform");
#endif
        }

        public void LaunchOnboarding(
            string clientID,
            string authToken)
        {
            sdkWrapper?.InitSdk(clientID, authToken);
            sdkWrapper?.LaunchOnboarding();
        }
    }
}