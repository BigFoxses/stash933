#import "stashutils.h"

#define AppsPath @"/Applications/"
#define AppsStash @"/var/stash/appsstash"
#ifdef __LP64__
#define AppExecutableLoader @"/usr/local/bin/CSStashedAppExecutable64"
#else
#define AppExecutableLoader @"/usr/local/bin/CSStashedAppExecutable"
#endif

NSMutableArray *possibleIconSizesForFileName(NSString *fileName){
	NSMutableArray *possibleFileNames = [NSMutableArray array];
	[possibleFileNames addObject:[fileName stringByAppendingString:@".png"]];
	[possibleFileNames addObject:[fileName stringByAppendingString:@"~ipad.png"]];
	[possibleFileNames addObject:[fileName stringByAppendingString:@"@2x.png"]];
	[possibleFileNames addObject:[fileName stringByAppendingString:@"@2x~ipad.png"]];
	[possibleFileNames addObject:[fileName stringByAppendingString:@"@3x.png"]];
	return possibleFileNames;
}

NSMutableArray *possibleIconFileNamesForFileName(NSString *fileName){
	if (!fileNameIsOk(fileName))
		return nil;

	if ([fileName hasSuffix:@".png"])
		fileName = [fileName stringByDeletingPathExtension];

	NSMutableArray *possibleFileNames = [NSMutableArray array];
	[possibleFileNames addObjectsFromArray:possibleIconSizesForFileName(fileName)];
	[possibleFileNames addObjectsFromArray:possibleIconSizesForFileName([fileName stringByAppendingString:@"-72"])];
	[possibleFileNames addObjectsFromArray:possibleIconSizesForFileName([fileName stringByAppendingString:@"-Small-50"])];
	[possibleFileNames addObjectsFromArray:possibleIconSizesForFileName([fileName stringByAppendingString:@"-Small"])];
	return possibleFileNames;
}

bool deStashAppExecutable(NSString *executablePath, NSString *stashedExecutablePath){
	if (![[NSFileManager defaultManager] fileExistsAtPath:stashedExecutablePath])
		return true;

	if (!deleteFile(executablePath, 1))
		return false;

	if (!copyFile(stashedExecutablePath, executablePath))
		return false;

	return true;
}

bool stashAppExecutable(NSString *executablePath, NSString *stashedExecutablePath){
	NSString *binaryStrings = outputFromCommand(@"/usr/bin/strings", @[executablePath]);
	if ([binaryStrings rangeOfString:@"=======*=======*=======CSSTASHEDAPPEXECUTABLESIGNATURE=======*=======*======="].location != NSNotFound){
		return true;
	}

	if ([[NSFileManager defaultManager] fileExistsAtPath:stashedExecutablePath]){
		if (!deleteFile(stashedExecutablePath, 1))
			return false;
	}

	if (!copyFile(executablePath, stashedExecutablePath))
		return false;

	if (!deleteFile(executablePath, 1))
		return false;

	if (!copyFile(AppExecutableLoader, executablePath))
		return false;

	return true;
}

bool handleCrashReporterQuirk(NSString *appPath, NSString *stashPath){
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSArray *stashContents = [fileManager contentsOfDirectoryAtPath:stashPath error:nil];
	for (NSString *fileName in stashContents){
		if ([fileName hasSuffix:@".dylib"]){
			NSString *stashedFilePath = [stashPath stringByAppendingPathComponent:fileName];
			NSString *filePath = [appPath stringByAppendingPathComponent:fileName];

			if (deStashFile(filePath, stashedFilePath)){
				NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];

				NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
				double rawFileSize = [fileSizeNumber doubleValue];
				NSString *fileSize = humanReadableFileSize(rawFileSize);

				printf("WARNING: Detected problematic packaging in CrashReporter. (%s exists in app bundle)\n",[fileName UTF8String]);
				printf("WARNING: Lost %s on / due to CrashReporter workaround!\n",[fileSize UTF8String]);
			}
		}
	}
	return true;
}

bool handleTransmissionQuirk(NSString *executablePath, NSString *stashedExecutablePath){
	NSString *binaryStrings = outputFromCommand(@"/usr/bin/strings", @[executablePath]);
	if ([binaryStrings rangeOfString:@"=======*=======*=======CSSTASHEDAPPEXECUTABLESIGNATURE=======*=======*======="].location != NSNotFound){
		if (![[NSFileManager defaultManager] fileExistsAtPath:stashedExecutablePath]){
			return false;
		}

		if (!deleteFile(executablePath, 1))
			return false;

		if (!copyFile(stashedExecutablePath, executablePath))
			return false;

		if (!deleteFile(stashedExecutablePath, 1))
			return false;

		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:executablePath error:nil];

		NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
		double rawFileSize = [fileSizeNumber doubleValue];
		NSString *fileSize = humanReadableFileSize(rawFileSize);

		printf("WARNING: iTransmission known to be problematic. (crash if app binary stashed)\n");
		printf("WARNING: Lost %s on / due to iTransmission workaround!\n",[fileSize UTF8String]);
	}
	return true;
}

bool stashApp(NSString *appPath)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSString *appName = [appPath lastPathComponent];

	NSString *appStash = [AppsStash stringByAppendingPathComponent:appName];
    if (![fileManager fileExistsAtPath:appStash])
			[fileManager createDirectoryAtPath:appStash withIntermediateDirectories:YES attributes:nil error:nil];

	if (![fileManager fileExistsAtPath:appStash]){
		printf("Error: Unable to create folder at %s\n",[AppsStash UTF8String]);
		return false;
	}

	NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];

	NSString *executableName = [infoPlist objectForKey:@"CFBundleExecutable"];
	NSString *executablePath = [appPath stringByAppendingPathComponent:executableName];
	NSString *stashedExecutablePath = [appStash stringByAppendingPathComponent:executableName];

	NSMutableArray *iconFiles = [NSMutableArray array];
	[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName([infoPlist objectForKey:@"CFBundleIconFile"])];

	[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName(@"Icon")];
	[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName(@"icon")];

	for (NSString *iconFileName in [infoPlist objectForKey:@"CFBundleIconFiles"]){
		[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName(iconFileName)];
	}

	if ([infoPlist objectForKey:@"CFBundleIcons"]){
		NSDictionary *icons = [infoPlist objectForKey:@"CFBundleIcons"];
		if ([icons isKindOfClass:[NSDictionary class]]){
			if ([icons objectForKey:@"CFBundlePrimaryIcon"]){
				NSDictionary *primaryIcons = [icons objectForKey:@"CFBundlePrimaryIcon"];
				if ([primaryIcons isKindOfClass:[NSDictionary class]]){
					NSArray *bundleIconFiles = [primaryIcons objectForKey:@"CFBundleIconFiles"];
					for (NSString *iconFileName in bundleIconFiles){
						[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName(iconFileName)];
					}
				}
			}
		}
	}

	if ([infoPlist objectForKey:@"CFBundleIcons~ipad"]){
		NSDictionary *icons = [infoPlist objectForKey:@"CFBundleIcons~ipad"];
		if ([icons isKindOfClass:[NSDictionary class]]){
			if ([icons objectForKey:@"CFBundlePrimaryIcon"]){
				NSDictionary *primaryIcons = [icons objectForKey:@"CFBundlePrimaryIcon"];
				if ([primaryIcons isKindOfClass:[NSDictionary class]]){
					NSArray *bundleIconFiles = [primaryIcons objectForKey:@"CFBundleIconFiles"];
					for (NSString *iconFileName in bundleIconFiles){
						[iconFiles addObjectsFromArray:possibleIconFileNamesForFileName(iconFileName)];
					}
				}
			}
		}
	}

	NSString *stashedInfoPlistPath = [appStash stringByAppendingPathComponent:@"Info.plist"];
	deleteFile(stashedInfoPlistPath, 0);

	NSArray *appContents = [fileManager contentsOfDirectoryAtPath:appPath error:nil];
	for (NSString *fileName in appContents){
		NSString *filePath = [appPath stringByAppendingPathComponent:fileName];
		NSString *stashedFilePath = [appStash stringByAppendingPathComponent:fileName];

		if (isSymbolicLink(filePath))
			continue;

		BOOL isDirectory;
		[fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
		
		if (isDirectory){
			if (!stashFile(filePath, stashedFilePath))
				return false;
			continue;
		}

		if ([fileName isEqualToString:@"Info.plist"]){
			linkFile(filePath, stashedFilePath);
			continue;
		}

		if ([iconFiles containsObject:fileName]){
			if ([fileManager fileExistsAtPath:stashedFilePath])
				deleteFile(stashedFilePath, 1);
			linkFile(filePath, stashedFilePath);
			continue;
		}

		if ([fileName isEqualToString:executableName]){
			continue;
		}

		if (!stashFile(filePath, stashedFilePath))
			return false;
		continue;
	}

	for (NSString *iconFileName in iconFiles){
		if (fileNameIsOk(iconFileName)){
			NSString *filePath = [appPath stringByAppendingPathComponent:iconFileName];
			NSString *stashedFilePath = [appStash stringByAppendingPathComponent:iconFileName];
			deStashFile(filePath, stashedFilePath);
		}
	}

	NSArray *appStashContents = [fileManager contentsOfDirectoryAtPath:appStash error:nil];
	for (NSString *fileName in appStashContents){
		NSString *filePath = [appPath stringByAppendingPathComponent:fileName];
		NSString *stashedFilePath = [appStash stringByAppendingPathComponent:fileName];

		if (isSymbolicLink(filePath))
			continue;

		if ([fileName isEqualToString:executableName])
			continue;

		if ([fileName isEqualToString:@"Info.plist"] && isSymbolicLink(stashedFilePath) && [fileManager fileExistsAtPath:filePath])
			continue;

		if ([iconFiles containsObject:fileName] && [fileManager fileExistsAtPath:filePath])
			continue;

		printf("Found orphan file at %s. Removing...\n",[stashedFilePath UTF8String]);
		deleteFile(stashedFilePath, 1);
	}

	if ([[appName lowercaseString] isEqualToString:@"crashreporter.app"]){
		if (handleCrashReporterQuirk(appPath, appStash))
			return true;
	}

	if (!stashAppExecutable(executablePath, stashedExecutablePath)){
		printf("Unable to stash app executable %s!\n", [executablePath UTF8String]);
		return false;
	}

	if ([[appName lowercaseString] isEqualToString:@"itransmission.app"])
		if (!handleTransmissionQuirk(executablePath, stashedExecutablePath))
			return false;

	return true;
}

bool isApp(NSString *appPath){
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isFolder;
	if (![fileManager fileExistsAtPath:appPath isDirectory:&isFolder])
		return false;

	if (!isFolder)
		return false;

	NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];

	if (![fileManager fileExistsAtPath:infoPlistPath])
		return false;
	return true;
}

void stashAppMain(){
	printf("Stash933 App Stasher Version 1.2.2\n");
	printf("Copyright 2016, CoolStar.\n");

	printf("Please wait, scanning apps...\n");
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSArray *apps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:AppsPath error:nil];
	for (NSString *app in apps){
		if ([[app lowercaseString] isEqualToString:@"cydia.app"])
			continue;

		NSString *appPath = [AppsPath stringByAppendingPathComponent:app];
		NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];

		if (![fileManager fileExistsAtPath:infoPlistPath])
			continue;

		NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
		NSString *bundleId = [infoPlist objectForKey:@"CFBundleIdentifier"];
		if ([bundleId hasPrefix:@"com.apple."])
			continue;

		printf("Stashing %s\n",[appPath UTF8String]);
		stashApp(appPath);
	}

	printf("Please wait, scanning for orphaned apps...\n");
	NSArray *stashedApps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:AppsStash error:nil];
	for (NSString *app in stashedApps){
		NSString *appPath = [AppsPath stringByAppendingPathComponent:app];
		NSString *stashedAppPath = [AppsStash stringByAppendingPathComponent:app];

		if (isApp(appPath))
			continue;

		printf("Orphan app found at %s. Removing...\n", [stashedAppPath UTF8String]);
		deleteFile(stashedAppPath, 1);
		if (isSymbolicLink(appPath))
			deleteFile(appPath, 1);
	}
	printf("Done stashing apps.\n");
}