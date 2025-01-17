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
    }
}