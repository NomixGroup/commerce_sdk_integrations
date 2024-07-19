using UnityEngine;

namespace AppnomixCommerce
{
    public class AppnomixAndroidCommerceSDK : IAppnomixCommerceSDK
    {
        public void InitSdk(
            string clientID, 
            string authToken, 
            string appGroupName_iOS, // e.g. group.app.appnomix.demo-unity
            string onboardingLogoAssetName, 
            string appURLScheme_iOS, // e.g. savers-league-coupons://
            bool requestLocation, 
            bool requestTracking)
        {
            string facadeClassName = "app.appnomix.sdk.external.CouponsSdkFacade";
            string configClassName = "app.appnomix.sdk.external.CouponsSdkFacade$Config";
            string logoImageResourceName = "logo_image"; // Name of the drawable resource
            try
            {
                // Get the activity instance
                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");

                // Load the drawable resource
                AndroidJavaObject resources = currentActivity.Call<AndroidJavaObject>("getResources");
                int appIconRes = resources.Call<int>("getIdentifier", logoImageResourceName, "drawable",
                    currentActivity.Call<string>("getPackageName"));

                // Create Config instance
                AndroidJavaObject configInstance = new AndroidJavaObject(configClassName, appIconRes, authToken, clientID);

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
