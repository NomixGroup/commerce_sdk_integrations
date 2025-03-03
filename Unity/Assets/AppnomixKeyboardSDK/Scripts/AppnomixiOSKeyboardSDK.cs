#if UNITY_IOS

using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixKeyboardSDK.Scripts
{
    public class AppnomixiOSKeyboardSDK : IAppnomixKeyboardSDK
    {
        // [DllImport("__Internal")]
        // private static extern void AppnomixKeyboardSDK_start(
        //     string clientID,
        //     string authToken,
        //     string appGroupName);

        // [DllImport("__Internal")]
        // private static extern void AppnomixKeyboardSDK_showOnboarding(AnalyticsEventCallback callback = null);

        private readonly string clientID;
        private readonly string authToken;
        private readonly string appGroupName;

        public AppnomixiOSKeyboardSDK(
            string clientID,
            string authToken,
            string appGroupName
        )
        {
            this.clientID = clientID;
            this.authToken = authToken;
            this.appGroupName = appGroupName;

            InitSdk();
        }

        private void InitSdk()
        {
            try
            {
                // AppnomixKeyboardSDK_start(
                //     clientID,
                //     authToken,
                //     appGroupName);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to call SDK initializer: " + e.Message);
            }
        }

        public void LaunchOnboarding()
        {
            try
            {
                // AppnomixKeyboardSDK_showOnboarding(callback);
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to show onboarding: " + e.Message);
            }
        }
    }
}

#endif
