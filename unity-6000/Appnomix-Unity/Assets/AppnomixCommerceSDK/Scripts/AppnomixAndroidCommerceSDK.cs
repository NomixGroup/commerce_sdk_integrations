using AppnomixCommerceSDK.Scripts;
using UnityEngine;

namespace AppnomixCommerceSDK.Scripts
{
#if UNITY_ANDROID
    public class AppnomixEventListenerProxy : AndroidJavaProxy
    {
        private readonly AnalyticsEventCallback _eventsDelegate;

        public AppnomixEventListenerProxy(AnalyticsEventCallback callback = null) : base(
            "app.appnomix.sdk.external.AppnomixEventListener")
        {
            _eventsDelegate = callback;
        }

        public void onAppnomixEvent(AndroidJavaObject eventObj)
        {
            string eventName = eventObj.Call<string>("name");
            Debug.Log($"Received event: {eventName}");

            switch (eventName)
            {
                case "ONBOARDING_STARTED":
                    Debug.Log("Onboarding started");
                    _eventsDelegate((long)AnalyticsEvent.OnboardingStarted);
                    break;
                case "ONBOARDING_ABANDONED":
                    Debug.Log("Onboarding abandoned");
                    _eventsDelegate((long)AnalyticsEvent.OnboardingDropout);
                    break;
                case "ONBOARDING_FINISHED":
                    Debug.Log("Onboarding finished");
                    _eventsDelegate((long)AnalyticsEvent.OnboardingCompleted);
                    break;
                default:
                    Debug.Log("Unknown event received");
                    break;
            }
        }
    }

    public class AppnomixAndroidCommerceSDK : IAppnomixCommerceSDK
    {
        private readonly string _clientID;
        private readonly string _authToken;
        private readonly string _language;
        private readonly AndroidJavaObject _couponsSdkFacade;

        public AppnomixAndroidCommerceSDK(
            string clientID,
            string authToken,
            string language
        )
        {
            _clientID = clientID;
            _authToken = authToken;
            _language = language;

            using (var sdkClass = new AndroidJavaClass("app.appnomix.sdk.external.CouponsSdkFacade"))
            {
                _couponsSdkFacade = sdkClass.GetStatic<AndroidJavaObject>("INSTANCE"); // If it's a singleton pattern
            }

            InitSdk();
        }

        private void InitSdk()
        {
            string configClassName = "app.appnomix.sdk.external.CouponsSdkFacade$Config";
            try
            {
                // TODO - fix this in SDK
                string language = _language == "" ? null : _language;
                AndroidJavaObject configInstance = new AndroidJavaObject(configClassName, _authToken, _clientID, language);

                _couponsSdkFacade.Call("setup", configInstance);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to call setup method: " + e.Message);
            }
        }

        public void LaunchOnboarding(AnalyticsEventCallback callback = null)
        {
            try
            {
                var listenerProxy = new AppnomixEventListenerProxy(callback);
                _couponsSdkFacade.Call("registerEventListener", listenerProxy);

                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                string customizationJson = SDKCustomizationScript.CustomizationJson;
                if (customizationJson.Length == 0)
                {
                    _couponsSdkFacade.Call("launchSdkOnboardingActivity", currentActivity);
                }
                else
                {
                    _couponsSdkFacade.Call("launchSdkOnboardingActivity", currentActivity, customizationJson);
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to launch SDK onboarding activity: " + e.Message);
            }
        }

        public bool IsOnboardingDone()
        {
            try
            {
                return _couponsSdkFacade.Call<bool>("isAccessibilityServiceEnabled");
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to get SDK onboarding status: " + e.Message);
                return false;
            }
        }

        public void TrackOfferDisplay(string context)
        {
            try
            {
                _couponsSdkFacade.Call("trackOfferDisplay", context);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to track offer display analytics: " + e.Message);
            }
        }
    }
#endif
}