using AppnomixCommerceSDK.Scripts;
using UnityEngine;

namespace AppnomixCommerceSDK.Scripts
{
#if UNITY_EDITOR
    public class AppnomixEditorCommerceSDK : IAppnomixCommerceSDK
    {
        private bool isOnboardingDone = false;

        private void InitSdk()
        {
            Debug.Log("AppnomixCommerceSDKWrapper is initialized in Editor env.");
        }

        public void LaunchOnboarding(AnalyticsEventCallback callback = null)
        {
            callback.Invoke((long)AnalyticsEvent.OnboardingStarted);
            callback.Invoke((long)AnalyticsEvent.OnboardingCompleted);
            isOnboardingDone = true;
        }

        public bool IsOnboardingDone()
        {
            Debug.Log("AppnomixCommerceSDKWrapper is working in Editor Env");
            return isOnboardingDone;
        }

        public void TrackOfferDisplay(string context)
        {
        }
    }
#endif
}