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
            if (Directory.Exists(pathToBuiltProject)) {
                Debug.Log("Running Appnomix PostProcessBuild script");
                IOSPostProcessBuild(target, pathToBuiltProject);
                AndroidOnPostProcessBuild(target, pathToBuiltProject);
            }
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
                UpdateGradleWrapper(pathToBuiltProject);
                UpdateGradleBuildFiles(pathToBuiltProject, "8.1.0", 35, "35.0.0");
                AddAppnomixDependency(pathToBuiltProject);
            }
        }

        private static void UpdateGradleProperties(string pathToBuiltProject)
        {
            string gradlePropertiesPath = Path.Combine(pathToBuiltProject, "gradle.properties");
            if (File.Exists(gradlePropertiesPath))
            {
                string content = File.ReadAllText(gradlePropertiesPath);

				string java17Path = Java17Finder.FindJava17Path();
                if (string.IsNullOrEmpty(java17Path))
                {
                    Debug.LogError("Java 17 not found. Please install Java 17 and try again.");
                    return;
                }

				Debug.Log($"Using Java 17 path: {java17Path}");

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

        private static void UpdateGradleBuildFiles(string pathToBuiltProject, string agpVersion, int compileSdkVersion,
            string buildToolsVersion)
        {
            string[] gradleFiles = Directory.GetFiles(pathToBuiltProject, "build.gradle", SearchOption.AllDirectories);

            foreach (string gradleFilePath in gradleFiles)
            {
                string content = File.ReadAllText(gradleFilePath);

                // Update Gradle Plugin version
                content = Regex.Replace(content, @"id\s+'com\.android\.application'\s+version\s+'\d+\.\d+(\.\d+)?'",
                    match => EnsurePluginVersion(match.Value, agpVersion));
                content = Regex.Replace(content, @"id\s+'com\.android\.library'\s+version\s+'\d+\.\d+(\.\d+)?'",
                    match => EnsurePluginVersion(match.Value, agpVersion));

                // Update compileSdkVersion and buildToolsVersion
                content = UpdateCompileSdkAndBuildTools(content, compileSdkVersion, buildToolsVersion);

                // Update compileOptions for Java 17 compatibility
                content = UpdateCompileOptions(content, gradleFilePath);

                File.WriteAllText(gradleFilePath, content);
                Debug.Log(
                    $"Updated {gradleFilePath} with AGP version {agpVersion}, compileSdkVersion {compileSdkVersion}, buildToolsVersion {buildToolsVersion}, and Java 17 compatibility.");
            }
        }

        private static string EnsureGradleVersion(string content, string targetVersion)
        {
            string pattern =
                @"distributionUrl=https\\://services.gradle.org/distributions/gradle-(\d+\.\d+(\.\d+)?)(.*)\.zip";

            return Regex.Replace(content, pattern, match =>
            {
                string currentVersion = match.Groups[1].Value;
                return IsVersionLower(currentVersion, targetVersion)
                    ? $"distributionUrl=https\\://services.gradle.org/distributions/gradle-{targetVersion}-all.zip"
                    : match.Value;
            });
        }

        private static string EnsurePluginVersion(string line, string targetVersion)
        {
            string pattern = @"version\s+'(\d+\.\d+(\.\d+)?)'";
            return Regex.Replace(line, pattern, match =>
            {
                string currentVersion = match.Groups[1].Value;
                return IsVersionLower(currentVersion, targetVersion)
                    ? $"version '{targetVersion}'"
                    : match.Value;
            });
        }

        private static string UpdateCompileSdkAndBuildTools(string content, int compileSdkVersion,
            string buildToolsVersion)
        {
            // Update compileSdkVersion
            content = Regex.Replace(content, @"compileSdkVersion\s+\d+", match =>
            {
                int currentVersion = int.Parse(match.Value.Split(' ')[1]);
                return currentVersion < compileSdkVersion
                    ? $"compileSdkVersion {compileSdkVersion}"
                    : match.Value;
            });

            // Update buildToolsVersion
            content = Regex.Replace(content, @"buildToolsVersion\s+'.*?'", match =>
            {
                string currentVersion = match.Value.Split('\'')[1];
                return IsVersionLower(currentVersion, buildToolsVersion)
                    ? $"buildToolsVersion '{buildToolsVersion}'"
                    : match.Value;
            });

            return content;
        }

        private static string UpdateCompileOptions(string content, string gradleFilePath)
        {
            // Avoid modifying the root build.gradle file
            if (gradleFilePath.EndsWith("build.gradle") && gradleFilePath.Contains("launcher") == false && gradleFilePath.Contains("unityLibrary") == false)
            {
                Debug.Log("Skipping compileOptions update for root build.gradle.");
                return content;
            }

            string compileOptionsBlock = @"compileOptions\s*\{\s*sourceCompatibility\s+JavaVersion\.VERSION_\d+.*?targetCompatibility\s+JavaVersion\.VERSION_\d+.*?\}";
            string updatedCompileOptions = @"compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
}";

            if (Regex.IsMatch(content, compileOptionsBlock, RegexOptions.Singleline))
            {
                content = Regex.Replace(content, compileOptionsBlock, match =>
                {
                    return IsVersionLower(match.Value, "17")
                        ? updatedCompileOptions
                        : match.Value;
                });
            }
            else
            {
                // Only append if it's not the root build.gradle
                content += "\n" + updatedCompileOptions;
            }

            return content;
        }
        
        private static void AddAppnomixDependency(string pathToBuiltProject)
        {
            string mainGradlePath = Path.Combine(pathToBuiltProject, "launcher", "build.gradle");
            if (File.Exists(mainGradlePath))
            {
                string content = File.ReadAllText(mainGradlePath);

                // Check if the dependency is already present
                if (!content.Contains("implementation 'app.appnomix:sdk:1.1.1'"))
                {
                    // Find the dependencies block and add the dependency
                    content = Regex.Replace(content, @"dependencies\s*\{", match =>
                    {
                        return $"{match.Value}\n    implementation 'app.appnomix:sdk:1.1.1'";
                    });

                    File.WriteAllText(mainGradlePath, content);
                    Debug.Log("Added Appnomix dependency to the main build.gradle.");
                }
                else
                {
                    Debug.Log("Appnomix dependency already exists in the main build.gradle.");
                }
            }
            else
            {
                Debug.LogWarning("Main build.gradle file not found. Unable to add Appnomix dependency.");
            }
        }

        private static bool IsVersionLower(string currentVersion, string targetVersion)
        {
            var current = currentVersion.Split('.').Select(int.Parse).ToArray();
            var target = targetVersion.Split('.').Select(int.Parse).ToArray();

            for (int i = 0; i < Math.Max(current.Length, target.Length); i++)
            {
                int currentPart = i < current.Length ? current[i] : 0;
                int targetPart = i < target.Length ? target[i] : 0;

                if (currentPart < targetPart) return true;
                if (currentPart > targetPart) return false;
            }

            return false;
        }
    }
}