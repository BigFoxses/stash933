#include "stashutils.h"

BOOL checkMount(){
	BOOL rebootNeeded = NO;
	NSString *mountOutput = outputFromCommand(@"/sbin/mount", @[]);
	NSArray *mountPoints = [mountOutput componentsSeparatedByString:@"\n"];
	for (NSString *mountPoint in mountPoints){
		if ([mountPoint rangeOfString:@" on /private/var "].location == NSNotFound)
			continue;
		if ([mountPoint rangeOfString:@"nosuid"].location != NSNotFound)
			rebootNeeded = YES;
	}
	return rebootNeeded;
}

void editFsTab(){
	if (kCFCoreFoundationVersionNumber != 1348.00 && kCFCoreFoundationVersionNumber != 1348.22)
		return; //Only edit FSTab on iOS 10.0 - 10.2
	NSString *fstab = [NSString stringWithContentsOfFile:@"/etc/fstab" encoding:NSASCIIStringEncoding error:nil];
	NSMutableArray *mountPoints = [[fstab componentsSeparatedByString:@"\n"] mutableCopy];
	BOOL editNeeded = NO;
	NSUInteger idxToEdit = -1;
	for (NSString *mountPoint in mountPoints){
		if ([mountPoint rangeOfString:@" /private/var "].location == NSNotFound)
			continue;
		if ([mountPoint rangeOfString:@"nosuid"].location != NSNotFound){
			editNeeded = YES;
			idxToEdit = [mountPoints indexOfObject:mountPoint];
		}
	}
	if (editNeeded){
		copyFile(@"/etc/fstab",@"/etc/fstab.bak");
		[mountPoints replaceObjectAtIndex:idxToEdit withObject:@"/dev/disk0s1s2 /private/var hfs rw,nodev 0 2"];
		NSString *newFstab = [mountPoints componentsJoinedByString:@"\n"];
		[newFstab writeToFile:@"/etc/fstab" atomically:YES encoding:NSASCIIStringEncoding error:nil];
	}
}