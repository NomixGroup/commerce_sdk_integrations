using UnityEngine;

namespace AppnomixKeyboardSDK.Scripts
{

    public class AppnomixAndroidKeyboardSDK : IAppnomixKeyboardSDK
    {
        private readonly string _clientID;
        private readonly string _authToken;
        private readonly AndroidJavaObject _keyboardSdkFacade;

        public AppnomixAndroidKeyboardSDK() {
            using (var sdkClass = new AndroidJavaClass("app.appnomix.keyboard_sdk.AppnomixKeyboardSdkFacade"))
            {
                _keyboardSdkFacade = sdkClass.GetStatic<AndroidJavaObject>("INSTANCE"); // If it's a singleton pattern
            }
        }

        public void LaunchOnboarding()
        {
            try
            {
                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                _keyboardSdkFacade.Call("launchKeyaboardOnboardingActivity", currentActivity);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to launch SDK onboarding activity: " + e.Message);
            }
        }
    }
}