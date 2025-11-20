using AOT;
using AppnomixCommerceSDK.Scripts;
using TMPro;
using UnityEngine;

public class AppnomixSDKIntegration : MonoBehaviour
{
    public TMP_Text onboardingStatus;

    private static bool _textChanged;
    private static AnalyticsEvent? _analyticsEvent;

    private static AppnomixCommerceSDKWrapper _sdk;

    void Start()
    {
        Debug.Log("AppnomixSDKIntegration Started");
        if (onboardingStatus != null)
        {
            onboardingStatus.text = "Onboarding";
        }

        _sdk ??= new AppnomixCommerceSDKWrapper(
            "YOUR_CLIENT_ID", // clientID
            "YOUR_AUTH_TOKEN", // authToken
            "group.app.appnomix.SampleApplication", // iOSAppGroupName (e.g. group.app.appnomix.demo-unity)
            "sample-application://", // iOSAppURLScheme (e.g. savers-league-coupons://)
            "" // language: empty string for system default language
        );
    }

    [MonoPInvokeCallback(typeof(AnalyticsEventCallback))]
    public static void HandleAnalyticsEvent(long eventValue)
    {
        Debug.Log($"Analytics event received: {eventValue}");

        var analyticsEvent = (AnalyticsEvent)eventValue;

        switch (analyticsEvent)
        {
            case AnalyticsEvent.OnboardingStarted:
                // The event triggered when onboarding begins by displaying the screen
                break;
            case AnalyticsEvent.OnboardingDropout:
                // The event triggered when the user cancels the onboarding process
                break;
            case AnalyticsEvent.OnboardingCompleted:
                // The event triggered upon onboarding completion,
                // indicating that the extension was installed and/or permissions were granted
                break;
        }

        _analyticsEvent = analyticsEvent;
        _textChanged = true;
    }

    public void LaunchOnboarding()
    {
        if (!_sdk.IsOnboardingAvailable())
        {
            Debug.Log("Appnomix onboarding is not available.");
            return;
        }
        
        Debug.Log("Appnomix onboarding is starting.");
        _sdk.LaunchOnboarding(HandleAnalyticsEvent);
    }

    public void TrackOffer(string context)
    {
        _sdk.TrackOfferDisplay(context);
    }

    // Update is called once per frame
    void Update()
    {
        if (_textChanged && onboardingStatus != null)
        {
            _textChanged = false;
            onboardingStatus.text = _analyticsEvent?.ToString();
        }
    }
}