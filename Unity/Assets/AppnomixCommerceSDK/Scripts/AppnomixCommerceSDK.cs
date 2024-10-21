using UnityEngine;
using System.Runtime.InteropServices;
using System;


namespace AppnomixCommerce
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void OnboardingEventCallback(IntPtr eventStr);

    public interface IAppnomixCommerceSDK
    {
        void LaunchOnboarding(OnboardingEventCallback callback = null);

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

        public void LaunchOnboarding(OnboardingEventCallback callback = null)
        {
            sdkWrapper?.LaunchOnboarding(callback);
        }

        public bool IsOnboardingDone()
        {
            return sdkWrapper?.IsOnboardingDone() ?? false;
        }
    }
}