/*
 * Copyright (c) 2017, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "FileUtils.h"
#import "Logging.h"
#import "PsiFeedbackLogger.h"

@implementation FileUtils

/*!
 * downgradeFileProtectionToNone sets the file protection type of paths to NSFileProtectionNone
 * so that they can be read from or written to at any time.
 * Attributes of exceptions remain untouched.
 * This is required for VPN "Connect On Demand" to work.
 * NOTE: All files containing sensitive information about the user should have file protection level
 *       NSFileProtectionCompleteUntilFirstUserAuthentication at the minimum. This is solely required for protecting
 *       user's data.
 *
 * @param paths List of file or directory paths to downgrade to NSFileProtectionNone.
 * @param exceptions List of file or directory paths to exclude from the downgrade operation.
 * @return TRUE if operation finished successfully, FALSE otherwise.
 */
+ (BOOL)downgradeFileProtectionToNone:(NSArray<NSString *> *)paths withExceptions:(NSArray<NSString *> *)exceptions {
    for (NSString *path in paths) {
        if (![FileUtils setFileProtectionNoneRecursively:path withExceptions:exceptions]) {
            return FALSE;
        }
    }
    return TRUE;
}

+ (BOOL)setFileProtectionNoneRecursively:(NSString *)path withExceptions:(NSArray<NSString *> *)exceptions{

    NSError *err;
    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isDirectory;
    if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && ![exceptions containsObject:path]) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:&err];
        if (err) {

            [PsiFeedbackLogger error:@"Failed to get file attributes for path (%@) (%@)",
             [RedactionUtils filepath:path],
             [RedactionUtils error:err]];

            return FALSE;
        }

        if (![attrs[NSFileProtectionKey] isEqualToString:NSFileProtectionNone]) {
            [fm setAttributes:@{NSFileProtectionKey: NSFileProtectionNone} ofItemAtPath:path error:&err];
            if (err) {

                [PsiFeedbackLogger error:@"Failed to set the protection level of dir(%@)",
                 [RedactionUtils filepath:path]];

                return FALSE;
            }
        }

        if (isDirectory) {
            NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:path error:&err];
            if (err) {

                [PsiFeedbackLogger error:@"Failed to get contents of directory (%@) (%@)",
                 [RedactionUtils filepath:path],
                 [RedactionUtils error:err]];

            }

            for (NSString * item in contents) {
                if (![self setFileProtectionNoneRecursively:[path stringByAppendingPathComponent:item] withExceptions:exceptions]) {
                    return FALSE;
                }
            }
        }
    }

    return TRUE;
}

/**
 * Creates directory at dirURL if it doesn't exist.
 */
+ (NSError *)createDir:(NSURL *)dirURL {
    NSError *e = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtURL:dirURL withIntermediateDirectories:TRUE attributes:nil error:&e];
    return e;
}

#if DEBUG
// See comment in header
+ (void)listDirectory:(NSString *)dir resource:(NSString *)resource recursively:(BOOL)recurse {
    NSError *err;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *desc = [NSMutableArray array];
    NSMutableArray<NSString *> *subdirs = [NSMutableArray array];

    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:&err];
    if (err != nil) {
        LOG_DEBUG(@"Failed to get contents of directory (%@): %@", dir, err);
        return;
    }

    NSNumber *dirExcludedFromBackupResourceValue;
    // The URL must be of the file scheme ("file://"), otherwise the `setResourceValue:forKey:error`
    // operation will silently fail with: "CFURLCopyResourcePropertyForKey failed because passed URL
    // no scheme".
    NSURL *dirURLWithScheme = [NSURL fileURLWithPath:dir isDirectory:YES];

    BOOL succeeded = [dirURLWithScheme getResourceValue:&dirExcludedFromBackupResourceValue
                                                 forKey:NSURLIsExcludedFromBackupKey
                                                  error:&err];
    if (!succeeded) {
        LOG_DEBUG(@"Failed to get resource value of file %@: %@", dir, err);
    }

    NSDictionary *dirattrs = [fm attributesOfItemAtPath:dir error:&err];
    if (err) {
        [PsiFeedbackLogger errorWithType:@"FileUtils" message:@"ListingDir" object:err];
    }

    LOG_DEBUG(@"Dir (%@) attributes:%@", [dir lastPathComponent], dirattrs[NSFileProtectionKey]);

    [desc addObject:[NSString stringWithFormat:
                     @"{directory:%@, attributes:%@, excludedFromBackup:%@}",
                     dir,
                     dirattrs[NSFileProtectionKey],
                     dirExcludedFromBackupResourceValue]];

    if ([files count] > 0) {
        for (NSString *f in files) {
            NSString *file;
            if (![[f stringByDeletingLastPathComponent] isEqualToString:dir]) {
                file = [dir stringByAppendingPathComponent:f];
            } else {
                file = f;
            }

            BOOL isDir;
            [fm fileExistsAtPath:file isDirectory:&isDir];

            NSNumber *excludedFromBackupResourceValue;

            // The URL must be of the file scheme ("file://"), otherwise the `setResourceValue:forKey:error`
            // operation will silently fail with: "CFURLCopyResourcePropertyForKey failed because passed URL
            // no scheme".
            NSURL *fileURLWithScheme = [NSURL fileURLWithPath:file];

            BOOL succeeded = [fileURLWithScheme getResourceValue:&excludedFromBackupResourceValue
                                                          forKey:NSURLIsExcludedFromBackupKey
                                                           error:&err];
            if (!succeeded) {
                LOG_DEBUG(@"Failed to get resource value of file %@: %@", file, err);
            }

            NSDictionary *attrs = [fm attributesOfItemAtPath:file error:&err];
            if (err) {
                LOG_DEBUG(@"Failed to get attributes of file %@: %@", file, err);
            }

            [desc addObject:[NSString stringWithFormat:
                             @"{file:%@, type:%@, attributes:%@, excludedFromBackup:%@}",
                             [file lastPathComponent],
                             (isDir) ? @"dir" : @"file",
                             attrs[NSFileProtectionKey],
                             excludedFromBackupResourceValue]];

            if (isDir && recurse) {
                [subdirs addObject:file];
            }
        }

        NSString *fileDescriptions = [desc componentsJoinedByString:@", "];

        LOG_DEBUG(@"Resource (%@) Checking files at dir (%@): [%@]",
                  resource,
                  dir,
                  fileDescriptions);

        for (NSString *subdir in subdirs) {
            [FileUtils listDirectory:subdir resource:resource recursively:recurse];
        }
    }
}
#endif

@end
