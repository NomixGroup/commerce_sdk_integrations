using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace AppnomixCommerceSDK.Editor
{
    public class Java17Finder
    {

        public static string FindJava17Path()
        {
            string[] commonParentDirectories =
            {
                "/Library/Java/JavaVirtualMachines", // macOS
                "/usr/lib/jvm", // Linux
                "C:\\Program Files\\Java", // Windows
                "C:\\Program Files (x86)\\Java" // Windows (32-bit)
            };

            foreach (string parentDir in commonParentDirectories)
            {
                if (Directory.Exists(parentDir))
                {
                    var potentialJavaDirs = Directory.GetDirectories(parentDir);
                    foreach (string javaDir in potentialJavaDirs)
                    {
                        string javaHome = Path.Combine(javaDir, "Contents", "Home"); // macOS
                        if (!Directory.Exists(javaHome))
                            javaHome = javaDir; // Linux/Windows

                        if (IsJava17(javaHome))
                            return javaHome;
                    }
                }
            }

            return null;
        }

        private static bool IsJava17(string javaHome)
        {
            string javaBinary = Path.Combine(javaHome, "bin", "java");

            if (!File.Exists(javaBinary))
                return false;

            try
            {
                var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = javaBinary,
                        Arguments = "-version",
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };

                process.Start();

                // Java version information is usually written to stderr
                string output = process.StandardError.ReadToEnd();
                process.WaitForExit();

                // Check if output contains Java 17
                return output.Contains("17");
            }
            catch
            {
                return false; // If the command fails, assume it's not Java 17
            }
        }
    }
}