#import <stdio.h>
#import <unistd.h>
#import <getopt.h>
#import <spawn.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <objc/runtime.h>

@interface NSTask : NSObject
- (void)setLaunchPath:(NSString *)launchPath;
- (void)setArguments:(NSArray *)arguments;
- (void)setStandardOutput:(NSPipe *)output;
- (void)setStandardError:(NSPipe *)output;
- (void)launch;
@end

BOOL isSymbolicLink(NSString *path){
	struct stat buf;
	if (lstat([path UTF8String], &buf) < 0)
		return false;
	return S_ISLNK(buf.st_mode);
}

bool isExecutable(NSString *path)
{
    struct stat st;

    if (stat([path UTF8String], &st) < 0)
        return false;
    if ((st.st_mode & S_IEXEC) != 0)
        return true;
    return false;
}

extern char **environ;

int run_cmd(const char *cmd, const char **argv)
{
    pid_t pid;
    int status;
    status = posix_spawn(&pid, cmd, NULL, NULL, (char * const *)argv, environ);
    if (status == 0) {
        if (waitpid(pid, &status, 0) != -1) {
            return status;
        } else {
            return -1;
        }
    } else {
        return -1;
    }
}

NSString *outputFromCommand(NSString *command, NSArray *arguments){
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:command];
	[task setArguments:arguments];
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	NSPipe *pipeError = [NSPipe pipe];
	[task setStandardError:pipeError];
	NSFileHandle *fileHandle = [pipe fileHandleForReading];
	[task launch];
	NSData *data = [fileHandle readDataToEndOfFile];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

bool copyFile(NSString *origPath, NSString *newPath){
	const char *cpArgv[] = {"cp","-Rp",[origPath UTF8String], [newPath UTF8String], NULL};
	if (run_cmd("/bin/cp", cpArgv) != 0){
		printf("Error: Unable to copy %s!\n",[origPath UTF8String]);
		return false;
	}
	return true;
}

bool deleteFile(NSString *path, int required){
	const char *rmArgv[] = {"rm","-rf", [path UTF8String], NULL};
	if (run_cmd("/bin/rm", rmArgv) != 0){
		if (required == 1)
			printf("Error: Unable to delete %s!\n",[path UTF8String]);
		return false;
	}
	return true;
}

bool linkFile(NSString *target, NSString *linkName){
	const char *lnArgv[] = {"ln","-s", [target UTF8String], [linkName UTF8String], NULL};
	if (run_cmd("/bin/ln", lnArgv) != 0){
		return false;
	}
	return true;
}

NSString *humanReadableFileSize(double convertedValue){
	int multiplyFactor = 0;
	NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",@"PB", @"EB", @"ZB", @"YB",nil];

	while (convertedValue > 1024) {
		convertedValue /= 1024;
		multiplyFactor++;
	}

	return [NSString stringWithFormat:@"%4.2f %@",convertedValue, [tokens objectAtIndex:multiplyFactor]];
}

bool stashFile(NSString *origPath, NSString *stashPath){
	if (!copyFile(origPath, stashPath)){
		return false;
	}

	if (!deleteFile(origPath, 1)){
		return false;
	}

	if (!linkFile(stashPath, origPath)){
		return false;
	}
	return true;
}

bool copyPermissions(NSString *linkPath, NSString *stashPath){
	if (![[NSFileManager defaultManager] fileExistsAtPath:linkPath])
		return false;
	if (![[NSFileManager defaultManager] fileExistsAtPath:stashPath])
		return false;

	struct stat st;
	if (stat([stashPath UTF8String], &st) < 0)
        return false;
    lchown([linkPath UTF8String], st.st_uid, st.st_gid);
    lchmod([linkPath UTF8String],st.st_mode);
    return true;
}

bool fileNameIsOk(NSString *fileName){
	if (!fileName)
		return false;
	if ([fileName isEqualToString:@""])
		return false;
	if ([fileName isEqualToString:[fileName lastPathComponent]])
		return true;
	return false;
}

bool deStashFile(NSString *origPath, NSString *stashPath){
	if ([[NSFileManager defaultManager] fileExistsAtPath:origPath]){
		if (!isSymbolicLink(origPath))
			return true;
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:stashPath])
		return false;

	if ([[NSFileManager defaultManager] fileExistsAtPath:origPath]){
		if (!deleteFile(origPath, 1)){
			return false;
		}
	}

	if (!copyFile(stashPath, origPath)){
		return false;
	}

	if (!deleteFile(stashPath, 0)){
		printf("Warning: Unable to delete %s! Will be removed on next run.\n",[stashPath UTF8String]);
	}
	return true;
}