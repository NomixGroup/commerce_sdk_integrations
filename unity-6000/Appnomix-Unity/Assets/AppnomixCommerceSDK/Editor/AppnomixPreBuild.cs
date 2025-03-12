using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace AppnomixCommerceSDK.Editor
{
    public class AppnomixPreBuild : IPreprocessBuildWithReport
    {
        public int callbackOrder => 0;

        public void OnPreprocessBuild(BuildReport report)
        {
            string jsonContent = "";

            Debug.Log("AppnomixCommerceSDK.Editor.OnPreprocessBuild");
            string jsonPath = Path.Combine(Application.dataPath, "AppnomixCommerceSDK/SDKCUstomization/sdk_customization.json");
            if (File.Exists(jsonPath))
            {
                Debug.Log("SDKCUstomization.json exists. Running in customized mode.");
                jsonContent = File.ReadAllText(jsonPath);
                jsonContent = jsonContent.Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "");
            }
            else
            {
                Debug.Log("SDK customization.json not found. Running in default mode.");
            }

            string generatedCode = $@"
namespace AppnomixCommerceSDK.Scripts
{{
    public static class SDKCustomizationScript
    {{
        public const string CustomizationJson = ""{jsonContent}"";
    }}
}}";

            string outputPath = Path.Combine(Application.dataPath, "AppnomixCommerceSDK/Scripts/SDKCustomizationScript.cs");
            File.WriteAllText(outputPath, generatedCode);

            Debug.Log($"C# script generated successfully: {outputPath}");

            AssetDatabase.Refresh();
        }
    }
}