using Debug = UnityEngine.Debug;

namespace AppnomixKeyboardSDK.Scripts
{
    public interface IAppnomixKeyboardSDK
    {
        void LaunchOnboarding();
    }

    public class AppnomixKeyboardSDKWrapper
    {
        private readonly IAppnomixKeyboardSDK sdkWrapper;

        public AppnomixKeyboardSDKWrapper()
        {
#if UNITY_IOS
            sdkWrapper = new AppnomixiOSKeyboardSDK();
#elif UNITY_ANDROID
            sdkWrapper = new AppnomixAndroidKeyboardSDK();
#else
            Debug.LogError("Unsupported platform");
#endif
        }

        public void LaunchOnboarding()
        {
            sdkWrapper?.LaunchOnboarding();
        }
    }
}
