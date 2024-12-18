using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace AppnomixCommerceSDK.Editor
{
    public static class AppnomixPostBuild
    {
        [PostProcessBuild]
        public static void OnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
        {
            Debug.Log("Running Appnomix PostProcessBuild script");
            IOSPostProcessBuild(target, pathToBuiltProject);
            AndroidOnPostProcessBuild(target, pathToBuiltProject);
        }

        private static void IOSPostProcessBuild(BuildTarget target, string pathToBuiltProject)
        {
            if (target == BuildTarget.iOS)
            {
                // checking for dependencies (ruby)
                string shellScriptPath = Application.dataPath + "/AppnomixCommerceSDK/Editor/SetupDependencies.sh";

                Process proc = new Process();
                proc.StartInfo.FileName = "/bin/bash";
                proc.StartInfo.Arguments = $"\"{shellScriptPath}\" \"{pathToBuiltProject}\"";
                proc.StartInfo.UseShellExecute = false;
                proc.StartInfo.RedirectStandardOutput = true;
                proc.StartInfo.RedirectStandardError = true;
                proc.Start();

                string output = proc.StandardOutput.ReadToEnd();
                string error = proc.StandardError.ReadToEnd();

                proc.WaitForExit();

                Debug.Log("Ruby is installed.");
                Debug.Log(output);
                if (!string.IsNullOrEmpty(error))
                {
                    Debug.LogError(error);
                }

                // setup Xcode project
                shellScriptPath = Application.dataPath + "/AppnomixCommerceSDK/Editor/SetupXcode.sh";

                proc = new Process();
                proc.StartInfo.FileName = "/bin/bash";
                proc.StartInfo.Arguments = $"\"{shellScriptPath}\" \"{pathToBuiltProject}\"";
                proc.StartInfo.UseShellExecute = false;
                proc.StartInfo.RedirectStandardOutput = true;
                proc.StartInfo.RedirectStandardError = true;
                proc.Start();

                output = proc.StandardOutput.ReadToEnd();
                error = proc.StandardError.ReadToEnd();

                proc.WaitForExit();

                Debug.Log("Xcode project setup completed.");
                Debug.Log(output);
                if (!string.IsNullOrEmpty(error))
                {
                    Debug.Log($"ERROR:\n{error}");
                    // false errors are stoppping the process
                    //UnityEngine.Debug.LogError(error);
                }
            }
        }

        private static void AndroidOnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
        {
            if (target == BuildTarget.Android)
            {
                UpdateGradleProperties(pathToBuiltProject);
                UpdateBuildGradleFiles(pathToBuiltProject, "8.1.0"); // Update AGP to 8.1.0
                UpdateGradleWrapper(pathToBuiltProject);
            }
        }

        private static void UpdateGradleProperties(string pathToBuiltProject)
        {
            string gradlePropertiesPath = Path.Combine(pathToBuiltProject, "gradle.properties");
            if (File.Exists(gradlePropertiesPath))
            {
                string content = File.ReadAllText(gradlePropertiesPath);

                // Update or add necessary properties
                if (!content.Contains("org.gradle.jvmargs"))
                {
                    content += "\norg.gradle.jvmargs=-Xmx8192m -XX:MaxPermSize=512m -Dfile.encoding=UTF-8\n";
                }

                if (!content.Contains("android.suppressUnsupportedCompileSdk"))
                {
                    content += "\nandroid.suppressUnsupportedCompileSdk=35\n";
                }

                if (!content.Contains("android.enableJetifier"))
                {
                    content += "\nandroid.enableJetifier=true\n";
                }

                if (!content.Contains("android.enableD8"))
                {
                    content += "\nandroid.enableD8=true\n";
                }

                File.WriteAllText(gradlePropertiesPath, content);
                Debug.Log("Updated gradle.properties with necessary properties.");
            }
        }

        private static void UpdateBuildGradleFiles(string pathToBuiltProject, string agpVersion)
        {
            string javaHome = GetJavaHomeForJava17();
            if (string.IsNullOrEmpty(javaHome))
            {
                Debug.LogError("PostBuildProcessor: Java 17 not found. Please install Java 17 and try again.");
                return;
            }

            Debug.Log($"PostBuildProcessor: Detected Java 17 path: {javaHome}");

            string[] gradleFiles = Directory.GetFiles(pathToBuiltProject, "build.gradle", SearchOption.AllDirectories);

            foreach (string gradleFilePath in gradleFiles)
            {
                string content = File.ReadAllText(gradleFilePath);

                // Update Android Gradle Plugin version
                content = Regex.Replace(content, @"id\s+'com\.android\.application'\s+version\s+'\d+\.\d+\.\d+'",
                    $"id 'com.android.application' version '{agpVersion}'");
                content = Regex.Replace(content, @"id\s+'com\.android\.library'\s+version\s+'\d+\.\d+\.\d+'",
                    $"id 'com.android.library' version '{agpVersion}'");

                File.WriteAllText(gradleFilePath, content);
                Debug.Log($"Updated {gradleFilePath} with AGP version {agpVersion}.");

                string gradlePropertiesPath = Path.Combine(pathToBuiltProject, "gradle.properties");
                if (File.Exists(gradlePropertiesPath))
                {
                    string propertiesContent = File.ReadAllText(gradlePropertiesPath);
                    if (!propertiesContent.Contains("org.gradle.java.home"))
                    {
                        Debug.Log("PostBuildProcessor: Setting org.gradle.java.home to Java 17.");
                        propertiesContent += $"\norg.gradle.java.home={javaHome}\n";
                        File.WriteAllText(gradlePropertiesPath, propertiesContent);
                    }
                }
                else
                {
                    Debug.LogWarning("PostBuildProcessor: gradle.properties not found.");
                }
            }
        }

        private static void UpdateGradleWrapper(string pathToBuiltProject)
        {
            string gradleWrapperPath = Path.Combine(pathToBuiltProject, "gradle/wrapper/gradle-wrapper.properties");

            if (File.Exists(gradleWrapperPath))
            {
                string content = File.ReadAllText(gradleWrapperPath);

                // Update Gradle wrapper version
                content = EnsureGradleVersion(content, "8.9");

                File.WriteAllText(gradleWrapperPath, content);
                Debug.Log("Updated gradle-wrapper.properties to use Gradle 8.9.");
            }
        }

        private static string EnsureGradleVersion(string content, string targetVersion)
        {
            // Regex to match any Gradle version in the format gradle-X.X.X-all.zip
            string pattern =
                @"distributionUrl=https\\://services.gradle.org/distributions/gradle-(\d+\.\d+(\.\d+)?)(.*)\.zip";

            // Replace all matched versions lower than the target version
            content = Regex.Replace(content, pattern, match =>
            {
                var currentVersion = match.Groups[1].Value;
                return IsVersionLower(currentVersion, targetVersion) ? $"distributionUrl=https\\://services.gradle.org/distributions/gradle-{targetVersion}-all.zip" : match.Value; // Keep unchanged if version is not lower
            });

            return content;
        }

        private static bool IsVersionLower(string currentVersion, string targetVersion)
        {
            // Parse versions into arrays of integers (e.g., "7.4.2" => [7, 4, 2])
            var current = currentVersion.Split('.').Select(int.Parse).ToArray();
            var target = targetVersion.Split('.').Select(int.Parse).ToArray();

            // Compare version numbers
            for (var i = 0; i < Math.Max(current.Length, target.Length); i++)
            {
                var currentPart = i < current.Length ? current[i] : 0;
                var targetPart = i < target.Length ? target[i] : 0;

                if (currentPart < targetPart) return true;
                if (currentPart > targetPart) return false;
            }

            return false; // Versions are equal
        }

        private static string GetJavaHomeForJava17()
        {
            return Environment.GetEnvironmentVariable("JAVA_HOME") ??
                   (Application.platform == RuntimePlatform.WindowsEditor
                       ? @"C:\Program Files\Java\jdk-17"
                       : Application.platform == RuntimePlatform.OSXEditor
                           ? "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
                           : "/usr/lib/jvm/java-17-openjdk");
        }
    }
}