using UnityEngine;

namespace AppnomixCommerce
{
    public class AppnomixAndroidCommerceSDK : IAppnomixCommerceSDK
    {
        public void InitSdk(string clientID, string authToken)
        {
            string facadeClassName = "app.appnomix.sdk.external.CouponsSdkFacade";
            string configClassName = "app.appnomix.sdk.external.CouponsSdkFacade$Config";
            try
            {
                // Create Config instance
                AndroidJavaObject configInstance = new AndroidJavaObject(configClassName, null, authToken, clientID);

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

        public void LaunchOnboarding()
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
    }
}