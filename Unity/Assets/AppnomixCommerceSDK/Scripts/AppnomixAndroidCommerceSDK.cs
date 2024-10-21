using UnityEngine;

namespace AppnomixCommerce
{
    public class AppnomixAndroidCommerceSDK : IAppnomixCommerceSDK
    {
        private readonly string clientID;
        private readonly string authToken;

        public AppnomixAndroidCommerceSDK(
            string clientID,
            string authToken
        )
        {
            this.clientID = clientID;
            this.authToken = authToken;

            InitSdk();
        }

        private void InitSdk()
        {
            string facadeClassName = "app.appnomix.sdk.external.CouponsSdkFacade";
            string configClassName = "app.appnomix.sdk.external.CouponsSdkFacade$Config";
            try
            {
                // Create Config instance
                AndroidJavaObject configInstance = new AndroidJavaObject(configClassName, authToken, clientID);

                // Get the CouponsSdkFacade class
                AndroidJavaClass couponsSdkFacade = new AndroidJavaClass(facadeClassName);
                AndroidJavaObject sdkFacadeInstance = couponsSdkFacade.GetStatic<AndroidJavaObject>("INSTANCE");
                sdkFacadeInstance.Call("setup", configInstance);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to call setup method: " + e.Message);
            }
        }

        public void LaunchOnboarding(OnboardingEventCallback callback = null)
        {
            string facadeClassName = "app.appnomix.sdk.external.CouponsSdkFacade";
            try
            {
                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                AndroidJavaClass couponsSdkFacade = new AndroidJavaClass(facadeClassName);
                AndroidJavaObject sdkFacadeInstance = couponsSdkFacade.GetStatic<AndroidJavaObject>("INSTANCE");
                sdkFacadeInstance.Call("launchSdkOnboardingActivity", currentActivity);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to launch SDK onboarding activity: " + e.Message);
            }
        }

        public bool IsOnboardingDone()
        {
            string facadeClassName = "app.appnomix.sdk.external.CouponsSdkFacade";
            try
            {
                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                AndroidJavaClass couponsSdkFacade = new AndroidJavaClass(facadeClassName);
                AndroidJavaObject sdkFacadeInstance = couponsSdkFacade.GetStatic<AndroidJavaObject>("INSTANCE");
                return sdkFacadeInstance.Call<bool>("isAccessibilityServiceEnabled");
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to get SDK onboarding status: " + e.Message);
                return false;
            }
        }
    }
}