#import "stashutils.h"

#define BinsPath @"/usr/bin/"
#define BinsStash @"/var/stash/usrbin"
#define LibsPath @"/usr/lib/"
#define LibsStash @"/var/stash/usrlib"

NSMutableArray *binFileNames;
NSMutableArray *libFileNames;

void loadDatabase(){
	binFileNames = [[NSMutableArray alloc] init];
	libFileNames = [[NSMutableArray alloc] init];

	NSArray *packageWhiteList = @[
		@"base",
		@"cy+cpu.arm",
		@"cy+kernel.darwin",
		@"cy+lib.corefoundation",
		@"cy+model.iphone",
		@"cy+model.ipod",
		@"cy+model.ipad",
		@"cy+os.ios",
		@"profile.d",
		@"readline",
		@"apr-lib",
		@"apt7-lib",
		@"apt7-key",
		@"cydia-lproj",
		@"cydia",
		@"darwintools",
		@"debianutils",
		@"org.thebigboss.repo.icons",
		@"pcre",
		@"sed",
		@"shell-cmds",
		@"system-cmds",
		@"uikittools",
		@"dpkg",
		@"bash",
		@"diffutils",
		@"findutils",
		@"ncurses",
		@"tar",
		@"bzip2",
		@"gnupg",
		@"gzip",
		@"grep",
		@"lzma",
		@"pam",
		@"pam-modules",
		@"firmware-sbin",
		@"coreutils-bin",
		@"com.saurik.patcyh",
		@"ldid",
		@"firmware",
		@"com.chronic-dev.greenpois0n.corona",
		@"com.chronic-dev.greenpois0n.rocky-racoon",
		@"com.evad3rs.evasi0n",
		@"com.ih8sn0w-squiffy-winocm.p0sixspwn",
		@"com.evad3rs.evasi0n7",
		@"io.pangu.axe7",
		@"io.pangu.xuanyuansword8",
		@"taiguntether",
		@"taiguntether83x",
		@"io.pangu.fuxiqin9",
		@"io.pangu.loader",
		@"openssh",
		@"openssl",
		@"socat",
		@"net.angelxwind.safestrat",
		@"apt7",
		@"apt7-ssl",
		@"berkeleydb",
		@"curl",
		@"us.scw.afctwoadd",
		@"com.saurik.afc2d",
		@"taigafc2"
	];

	NSArray *lists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/var/lib/dpkg/info" error:nil];
	for (NSString *name in lists){
		if (![name hasSuffix:@".list"])
			continue;

		NSString *packageName = [name stringByDeletingPathExtension];

		if ([packageWhiteList containsObject:packageName])
			continue;

		NSString *binaryStrings = outputFromCommand(@"/usr/bin/dpkg", @[@"-s",packageName]);
		if ([binaryStrings rangeOfString:@"Status: install ok installed"].location == NSNotFound){
			continue;
		}

		NSString *fullListPath = [@"/var/lib/dpkg/info/" stringByAppendingPathComponent:name];
		NSString *rawList = [NSString stringWithContentsOfFile:fullListPath encoding:NSUTF8StringEncoding error:nil];
		NSArray *files = [rawList componentsSeparatedByString:@"\n"];
		for (NSString *file in files){	
			if ([file isEqualToString:BinsPath])
				continue;
			if ([file isEqualToString:LibsPath])
				continue;

			if (![file hasPrefix:BinsPath] && ![file hasPrefix:LibsPath])
				continue;

			NSString *nonPrefixedPath;
			if ([file hasPrefix:BinsPath])
				nonPrefixedPath = [file substringFromIndex:[BinsPath length]];
			if ([file hasPrefix:LibsPath])
				nonPrefixedPath = [file substringFromIndex:[LibsPath length]];

			if (![nonPrefixedPath isEqualToString:[nonPrefixedPath lastPathComponent]])
				continue;

			BOOL isDirectory = false;
			[[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory];
			if (isDirectory){
				printf("Folder detected at %s. Not stashing as folders aren't supported yet.\n",[file UTF8String]);
				continue;
			}

			if ([file hasPrefix:BinsPath])
				[binFileNames addObject:file];
			if ([file hasPrefix:LibsPath])
				[libFileNames addObject:file];
		}
	}
}

void stashBinLibMain(){
	printf("Stash933 CLI Tool/Library Stasher Version 1.0\n");
	printf("Copyright 2016, CoolStar.\n");

	printf("Please wait, reading database...\n");

	loadDatabase();

	NSFileManager *fileManager = [NSFileManager defaultManager];

	if (![fileManager fileExistsAtPath:BinsStash])
		[fileManager createDirectoryAtPath:BinsStash withIntermediateDirectories:YES attributes:nil error:nil];

	if (![fileManager fileExistsAtPath:BinsStash]){
		printf("Error: Unable to create folder at %s\n",[BinsStash UTF8String]);
		return;
	}

	for (NSString *filePath in binFileNames){
		if (isSymbolicLink(filePath))
			continue;

		NSString *fileName = [filePath lastPathComponent];

		NSString *stashedFilePath = [BinsStash stringByAppendingPathComponent:fileName];

		printf("Stashing Bin: %s\n",[fileName UTF8String]);
		stashFile(filePath, stashedFilePath);
		copyPermissions(filePath, stashedFilePath);
	}

	printf("Please wait, searching for orphaned binaries...\n");

	NSArray *binaries = [fileManager contentsOfDirectoryAtPath:BinsStash error:nil];
	for (NSString *fileName in binaries){
		NSString *filePath = [BinsPath stringByAppendingPathComponent:fileName];
		NSString *stashedFilePath = [BinsStash stringByAppendingPathComponent:fileName];

		if (isSymbolicLink(filePath))
			continue;

		printf("Removing orphaned binary at %s\n",[stashedFilePath UTF8String]);
		if (!deleteFile(stashedFilePath, 0)){
			printf("Failed to remove orphaned binary. Will remove on next run.\n");
		}
	}

	printf("Done stashing binaries.\n");

	if (![fileManager fileExistsAtPath:LibsStash])
		[fileManager createDirectoryAtPath:LibsStash withIntermediateDirectories:YES attributes:nil error:nil];

	if (![fileManager fileExistsAtPath:LibsStash]){
		printf("Error: Unable to create folder at %s\n",[LibsStash UTF8String]);
		return;
	}

	for (NSString *filePath in libFileNames){
		if (isSymbolicLink(filePath))
			continue;

		NSString *fileName = [filePath lastPathComponent];

		NSString *stashedFilePath = [LibsStash stringByAppendingPathComponent:fileName];

		printf("Stashing Lib: %s\n",[fileName UTF8String]);

		stashFile(filePath, stashedFilePath);
		copyPermissions(filePath, stashedFilePath);
	}

	printf("Please wait, searching for orphaned libraries...\n");

	NSArray *libraries = [fileManager contentsOfDirectoryAtPath:LibsStash error:nil];
	for (NSString *fileName in libraries){
		NSString *filePath = [LibsPath stringByAppendingPathComponent:fileName];
		NSString *stashedFilePath = [LibsStash stringByAppendingPathComponent:fileName];

		if (isSymbolicLink(filePath))
			continue;

		printf("Removing orphaned library at %s\n",[stashedFilePath UTF8String]);
		if (!deleteFile(stashedFilePath, 0)){
			printf("Failed to remove orphaned library. Will remove on next run.\n");
		}
	}

	printf("Done stashing libraries.\n");
}