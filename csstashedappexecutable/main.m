#define AppsStash @"/var/stash/appsstash"

int main(int argc, char **argv, char **envp) {
	@autoreleasepool {
		NSString *signature = [[NSString alloc] initWithString:@"=======*=======*=======CSSTASHEDAPPEXECUTABLESIGNATURE=======*=======*======="];
		[signature release];

		NSBundle *bundle = [NSBundle mainBundle];
		NSString *executableName = [[bundle executablePath] lastPathComponent];
		NSString *bundleName = [[bundle bundlePath] lastPathComponent];

		NSString *stashedBundlePath = [AppsStash stringByAppendingPathComponent:bundleName];

		NSString *stashedExecutablePath = [stashedBundlePath stringByAppendingPathComponent:executableName];

		execv([stashedExecutablePath cStringUsingEncoding:NSASCIIStringEncoding], argv); //chainload the app executable from stash path
	}
	return 0;
}

// vim:ft=objc
