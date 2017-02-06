#import <stdio.h>
#import <unistd.h>
#import <getopt.h>
#import <spawn.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <objc/runtime.h>

void stashAppMain();
void stashBinLibMain();
BOOL checkMount();
void editFsTab();

int main(int argc, char **argv, char **envp) {
	@autoreleasepool {
		bool needsReboot = checkMount();
		stashAppMain();
		stashBinLibMain();
		editFsTab();
		if (needsReboot){
			printf("Reboot Needed to update mount points...\n");
			char *cydia_env = getenv("CYDIA");
			if (cydia_env != NULL){
				int cydiaFd = (int)strtoul(cydia_env, NULL, 10);
				if (cydiaFd != 0)
					write(cydiaFd, "finish:reboot", 13);
			}
		}
	}
	return 0;
}

// vim:ft=objc
