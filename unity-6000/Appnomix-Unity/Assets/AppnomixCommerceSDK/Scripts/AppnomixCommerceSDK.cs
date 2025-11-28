using UnityEngine;
using System.Runtime.InteropServices;
using System;
using AppnomixCommerceSDK.Scripts;


namespace AppnomixCommerceSDK.Scripts
{
    public enum AnalyticsEvent : long
    {
        OnboardingStarted = 1001L,
        OnboardingDropout = 1002L,
        OnboardingCompleted = 1003L
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void AnalyticsEventCallback(long eventValue);

    public interface IAppnomixCommerceSDK
    {
        void ShowOnboarding(AnalyticsEventCallback callback = null);

        bool IsOnboardingDone();

        bool IsOnboardingAvailable();

        void TrackOfferDisplay(string context);
    }

    public class AppnomixCommerceSDKWrapper
    {
        private readonly IAppnomixCommerceSDK sdkWrapper;
        
        public AppnomixCommerceSDKWrapper(
            string clientID,
            string authToken,
            string iOSAppGroupName, // e.g. group.app.appnomix.demo-unity
            string iOSAppURLScheme, // e.g. savers-league-coupons://
            string language)
        {
#if UNITY_EDITOR
            sdkWrapper = new AppnomixEditorCommerceSDK();
#elif UNITY_IOS
            sdkWrapper = new AppnomixiOSCommerceSDK(
                            clientID,
                            authToken,
                            iOSAppGroupName,
                            iOSAppURLScheme,
                            language
                        );
#elif UNITY_ANDROID
            sdkWrapper = new AppnomixAndroidCommerceSDK(
                            clientID,
                            authToken,
                            language
                        );
#else
            Debug.LogError("Unsupported platform");
#endif
        }

        public void ShowOnboarding(AnalyticsEventCallback callback = null)
        {
            sdkWrapper?.ShowOnboarding(callback);
        }

        public bool IsOnboardingDone()
        {
            return sdkWrapper?.IsOnboardingDone() ?? false;
        }
        
        public bool IsOnboardingAvailable()
        {
            return sdkWrapper?.IsOnboardingAvailable() ?? false;
        }

        public void TrackOfferDisplay(string context)
        {
            sdkWrapper?.TrackOfferDisplay(context);
        }
    }
}