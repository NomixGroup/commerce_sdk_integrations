#if UNITY_IOS

using UnityEngine;
using System.Runtime.InteropServices;

namespace AppnomixKeyboardSDK.Scripts
{
    public class AppnomixiOSKeyboardSDK : IAppnomixKeyboardSDK
    {
        [DllImport("__Internal")]
        private static extern void AppnomixKeyboardSDK_showOnboarding();

        public AppnomixiOSKeyboardSDK()
        {
            InitSdk();
        }

        private void InitSdk()
        {
        }

        public void LaunchOnboarding()
        {
            try
            {
                AppnomixKeyboardSDK_showOnboarding();
            }
            catch (System.Exception e)
            {
                Debug.LogError("Failed to show onboarding: " + e.Message);
            }
        }
    }
}

#endif
