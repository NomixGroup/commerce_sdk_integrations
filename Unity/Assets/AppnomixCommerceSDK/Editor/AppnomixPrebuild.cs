using System.Diagnostics;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using System;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor.Callbacks;
using Debug = UnityEngine.Debug;

namespace AppnomixCommerceSDK.Editor
{
    public class AppnomixPrebuild : IPreprocessBuildWithReport
    {

        public int callbackOrder => 0;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (report.summary.platform == BuildTarget.Android)
            {
                string java17Path = Java17Finder.FindJava17Path();
                if (string.IsNullOrEmpty(java17Path))
                {
                    Debug.LogError("Java 17 not found. Please install Java 17 and try again.");
                    return;
                }

                Debug.Log($"Using Java 17 path: {java17Path}");

                // Set JAVA_HOME environment variable
                UpdateGradleProperties(report.summary.outputPath, java17Path);
            }
        }
        
        private void UpdateGradleProperties(string buildPath, string java17Path)
        {
            string gradlePropertiesPath = Path.Combine(buildPath, "gradle.properties");

            if (File.Exists(gradlePropertiesPath))
            {
                string content = File.ReadAllText(gradlePropertiesPath);

                // Add or update org.gradle.java.home
                if (content.Contains("org.gradle.java.home"))
                {
                    content = Regex.Replace(content, @"org\.gradle\.java\.home=.*", $"org.gradle.java.home={java17Path}");
                }
                else
                {
                    content += $"\norg.gradle.java.home={java17Path}\n";
                }

                File.WriteAllText(gradlePropertiesPath, content);
                Debug.Log("Updated gradle.properties with org.gradle.java.home.");
            }
        }
    }

}
