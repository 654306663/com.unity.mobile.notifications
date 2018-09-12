﻿using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Unity.Notifications.Android;
using Unity.Notifications.iOS;
using UnityEditor;
using UnityEditor.Callbacks;

using UnityEngine;

#if UNITY_IOS
using UnityEditor.iOS.Xcode;
#endif

public class iOSNotificationPostProcess : MonoBehaviour {

	[PostProcessBuild]
	public static void OnPostprocessBuild (BuildTarget buildTarget, string path)
	{
		#if UNITY_IOS
		if (buildTarget == BuildTarget.iOS) {
			
			var projPath = path + "/Unity-iPhone.xcodeproj/project.pbxproj";
				
			var proj = new PBXProject ();
			proj.ReadFromString (File.ReadAllText (projPath));			
			var target = proj.TargetGuidByName ("Unity-iPhone");
			
			var settings = UnityNotificationEditorManager.Initialize().iOSNotificationEditorSettingsFlat;

			var useReleaseAPSEnvSetting = settings
				.Find(i => i.key == "UnityAPSReleaseEnvironment");
			var useReleaseAPSEnv = false;
			
			if (useReleaseAPSEnvSetting != null)
				useReleaseAPSEnv = (bool)useReleaseAPSEnvSetting.val;

			var needLocationFramework = settings
				.Find(i => i.key == "UnityUseLocationNotificationTrigger") != null;;
			
			proj.AddFrameworkToProject(target, "UserNotifications.framework", useReleaseAPSEnv);
			
			if (needLocationFramework)
				proj.AddFrameworkToProject(target, "CoreLocation.framework", false);
			
			File.WriteAllText (projPath, proj.WriteToString ());
			
			var pbxPath = PBXProject.GetPBXProjectPath(path);
			var capManager = new ProjectCapabilityManager(pbxPath, string.Format("{0}.entitlements", PlayerSettings.productName), "Unity-iPhone");
			capManager.AddPushNotifications(true);
			capManager.WriteToFile();
			
			// Get plist
			var plistPath = path + "/Info.plist";
			var plist = new PlistDocument();
			plist.ReadFromString(File.ReadAllText(plistPath));
       
			// Get root
			var rootDict = plist.root;
			
			var requiredVersion = new Version(8, 0);
			bool hasMinOSVersion;
			
			try
			{
				var currentVersion = new Version(PlayerSettings.iOS.targetOSVersionString);
				hasMinOSVersion = currentVersion >= requiredVersion;
			}
			catch (Exception)
			{
				hasMinOSVersion = false;
			}
			
			if (!hasMinOSVersion)
				Debug.Log("UserNotifications is only available on iOS 10 and above, please make sure that you set a correct `Target minimum iOS Version` in Player Settings.");

			foreach (var setting in settings)
			{				
				if (setting.val.GetType() == typeof(bool))
					rootDict.SetBoolean(setting.key, (bool) setting.val);
				else if (setting.val.GetType() == typeof(PresentationOption))
					rootDict.SetInteger(setting.key, (int) setting.val);
			}

			// Write to file
			File.WriteAllText(plistPath, plist.WriteToString());
		
			//Get Preprocessor.h
			var preprocessorPath = path + "/Classes/Preprocessor.h";
			var preprocessor = File.ReadAllText(preprocessorPath);

			if (needLocationFramework)
				if (preprocessor.Contains("UNITY_USES_LOCATION"))
					preprocessor = preprocessor.Replace("UNITY_USES_LOCATION 0", "UNITY_USES_LOCATION 1");
						
			preprocessor = preprocessor.Replace("UNITY_USES_REMOTE_NOTIFICATIONS 0", "UNITY_USES_REMOTE_NOTIFICATIONS 1");
			File.WriteAllText(preprocessorPath, preprocessor);
		}
		#endif

	}

}
