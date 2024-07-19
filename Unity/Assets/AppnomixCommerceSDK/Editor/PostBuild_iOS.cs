using UnityEditor;
using UnityEditor.iOS.Xcode;
using UnityEditor.Callbacks;
using System.Diagnostics;
using System.IO;
using UnityEngine;

public static class PostProcessBuild
{
    [PostProcessBuild]
    public static void OnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
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

            UnityEngine.Debug.Log("Ruby is installed.");
            UnityEngine.Debug.Log(output);
            if (!string.IsNullOrEmpty(error))
            {
                UnityEngine.Debug.LogError(error);
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

            UnityEngine.Debug.Log("Xcode project setup completed.");
            UnityEngine.Debug.Log(output);
            if (!string.IsNullOrEmpty(error))
            {
                UnityEngine.Debug.Log($"ERROR:\n{error}");
                // false errors are stoppping the process
                //UnityEngine.Debug.LogError(error);
            }
        }
    }
}
