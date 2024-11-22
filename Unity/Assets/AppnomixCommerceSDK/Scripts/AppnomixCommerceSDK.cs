using UnityEngine;
using System.Runtime.InteropServices;
using System;


namespace AppnomixCommerce
{
    public enum AnalyticsEvent
    {
        OnboardingStarted = 1001,
        OnboardingDropout = 1002,
        OnboardingCompleted = 1003
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void AnalyticsEventCallback(long eventValue);

    public interface IAppnomixCommerceSDK
    {
        void LaunchOnboarding(AnalyticsEventCallback callback = null);

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

        public void LaunchOnboarding(AnalyticsEventCallback callback = null)
        {
            sdkWrapper?.LaunchOnboarding(callback);
        }

        public bool IsOnboardingDone()
        {
            return sdkWrapper?.IsOnboardingDone() ?? false;
        }
    }
}