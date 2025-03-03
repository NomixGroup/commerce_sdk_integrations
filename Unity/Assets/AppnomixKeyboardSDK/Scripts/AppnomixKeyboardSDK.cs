namespace AppnomixKeyboardSDK.Scripts
{
    public interface IAppnomixKeyboardSDK
    {
        void LaunchOnboarding();
    }

    public class AppnomixKeyboardSDKWrapper
    {
        private readonly IAppnomixKeyboardSDK sdkWrapper;

        public AppnomixKeyboardSDKWrapper(
            string clientID = null,
            string authToken = null,
            string iOSAppGroupName = null)
        {
#if UNITY_IOS
            sdkWrapper = new AppnomixiOSKeyboardSDK(
                            clientID,
                            authToken,
                            iOSAppGroupName
                        );
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
