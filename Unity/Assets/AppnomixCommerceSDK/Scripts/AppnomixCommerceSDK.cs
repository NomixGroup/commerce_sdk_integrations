using UnityEngine;

namespace AppnomixCommerce
{
    public interface IAppnomixCommerceSDK
    {
        void LaunchOnboarding();

        bool IsOnboardingDone();
    }

    public class AppnomixCommerceSDK
    {
        private readonly IAppnomixCommerceSDK sdkWrapper;

        public AppnomixCommerceSDK(
            string clientID,
            string authToken,
            string iOSAppGroupName, // e.g. group.app.appnomix.demo-unity
            string iOSAppURLScheme, // e.g. savers-league-coupons://
            bool requestLocation,
            bool requestTracking)
        {
#if UNITY_IOS
            sdkWrapper = new AppnomixiOSCommerceSDK(
                            clientID,
                            authToken,
                            iOSAppGroupName,
                            iOSAppURLScheme,
                            requestLocation,
                            requestTracking
                        );
#elif UNITY_ANDROID
            sdkWrapper = new AppnomixAndroidCommerceSDK(
                            clientID,
                            authToken
                        );
#else
            Debug.LogError("Unsupported platform");
#endif
        }

        public void LaunchOnboarding()
        {
            sdkWrapper?.LaunchOnboarding();
        }

        public bool IsOnboardingDone()
        {
            return sdkWrapper?.IsOnboardingDone() ?? false;
        }
    }
}