//
//  DiskManager.m
//  MyHouseMyRule
//
//  Created by kingcos on 2020/7/5.
//  Copyright © 2020 leave. All rights reserved.
//

#import "DiskManager.h"

#import "ShellCommand.h"
#import "NSArray+HighOrderFunction.h"

#pragma mark - DiskModel
@interface DiskModel ()

@property (nonatomic, copy) NSString *id;
@property (nonatomic, assign) DiskStatus status;
@property (nonatomic, assign) DiskPartitionType partitionType;

@end

@implementation DiskModel

- (instancetype)initWithID:(NSString *)id {
    self = [super init];
    if (self) {
        self.id = id;
    }
    return self;
}

- (BOOL)isMounted {
    NSString *output = nil;
    [ShellCommand runScript:[NSString stringWithFormat:@"diskutil info %@", self.id] output:&output];
    NSString *mountedLine = [[output componentsSeparatedByString:@"\n"] filter:^BOOL(NSString *obj) {
        return [obj containsString:@"Mounted:"];
    }].firstObject;
    
    return [mountedLine containsString:@"Yes"];
}

- (BOOL)isMountable {
    return ![self isMounted] && ![self isWhole] && self.partitionType != DiskPartitionTypeEFI;
}

- (BOOL)isWhole {
    NSString *output = nil;
    [ShellCommand runScript:[NSString stringWithFormat:@"diskutil info %@", self.id] output:&output];
    NSString *mountedLine = [[output componentsSeparatedByString:@"\n"] filter:^BOOL(NSString *obj) {
        return [obj containsString:@"Whole:"];
    }].firstObject;
    
    return [mountedLine containsString:@"Yes"];
}

- (DiskPartitionType)partitionType {
    if (!_partitionType) {
        NSString *output = nil;
        [ShellCommand runScript:[NSString stringWithFormat:@"diskutil info %@", self.id] output:&output];
        NSString *partitionTypeLine = [[output componentsSeparatedByString:@"\n"] filter:^BOOL(NSString *obj) {
            return [obj containsString:@"Partition Type:"];
        }].firstObject;
        
        _partitionType = DiskPartitionTypeUnknown;
        
        if ([partitionTypeLine containsString:@"EFI"]) {
            _partitionType = DiskPartitionTypeEFI;
        }
    }
    
    return _partitionType;
}

@end

#pragma mark - DiskManager
@implementation DiskManager

#pragma mark Public

+ (NSArray<DiskModel *> *)list {
    NSString *output = nil;
    [ShellCommand runScript:@"diskutil list" output:&output];
    NSArray <NSString *> *sections = [[output componentsSeparatedByString:@"\n\n"] filter:^BOOL(NSString *obj) {
        return obj.length != 0;
    }];
    
    NSMutableArray <DiskModel *> *models = [NSMutableArray array];
    [sections forEach:^(NSString *obj) {
        NSArray *lines = [obj componentsSeparatedByString:@"\n"];
//        /dev/disk0 (internal, physical):
//           #:                       TYPE NAME                    SIZE       IDENTIFIER
//           0:      GUID_partition_scheme                        *500.3 GB   disk0
//           1:                        EFI EFI                     314.6 MB   disk0s1
//           2:                 Apple_APFS Container disk1         500.0 GB   disk0s2
//
        DiskStatus status = [self _statusByLine:lines[0]];
        [lines forEach:^(NSString *obj) {
            //    0:      GUID_partition_scheme                        *500.3 GB   disk0
            NSArray *words = [[obj componentsSeparatedByString:@" "] filter:^BOOL(NSString *obj) {
                return obj.length != 0;
            }];
            if ([words count] < 4 || [words.firstObject containsString:@"#"]) { return; } // Skip for: /dev/disk1, (synthesized): && #
            
            DiskModel *model = [[DiskModel alloc] initWithID:words.lastObject];
            model.status = status;
            
            [models addObject:model];
        }];
    }];
    
    return models;
}

+ (DiskModel *)diskModelByID:(NSString *)id {
    NSArray *list = [[self list] filter:^BOOL(DiskModel *obj) { return obj.id == id; }];
    
    return list.firstObject;
}

+ (void)mountByID:(NSString *)id completion:(void (^)(NSError * _Nullable))completion {
    DiskModel *model = [self diskModelByID:id];
    if (!model) {
        if (completion) {
            completion([NSError errorWithDomain:NSCocoaErrorDomain code:10000 userInfo:@{NSLocalizedDescriptionKey : @"Error: Can not find disk by your id."}]);
        }
        return;
    }
    
    if (![model isMountable]) {
        if (completion) {
            completion([NSError errorWithDomain:NSCocoaErrorDomain code:10000 userInfo:@{NSLocalizedDescriptionKey : @"Error: The disk is already mounted."}]);
        }
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *output = @"";
        [ShellCommand runScript:[NSString stringWithFormat:@"diskutil mount %@", id] output:&output];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil);
            }
        });
    });
}

+ (void)unmountByID:(NSString *)id completion:(void (^)(NSError * _Nullable))completion {
    DiskModel *model = [self diskModelByID:id];
    if (!model) {
        if (completion) {
            completion([NSError errorWithDomain:NSCocoaErrorDomain code:10000 userInfo:@{NSLocalizedDescriptionKey : @"Error: Can not find disk by your id."}]);
        }
        return;
    }

    if (![model isMounted]) {
        if (completion) {
            completion([NSError errorWithDomain:NSCocoaErrorDomain code:10000 userInfo:@{NSLocalizedDescriptionKey : @"Error: The disk is already unmounted."}]);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *output = @"";
        [ShellCommand runScript:[NSString stringWithFormat:@"diskutil unmount %@", id] output:&output];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil);
            }
        });
    });
}

#pragma mark Private
+ (DiskStatus)_statusByLine:(NSString *)line {
    DiskStatus status = DiskStatusNone;
    
    if ([line containsString:@"internal"]) {
        status = status | DiskStatusInternal;
    }
    
    if ([line containsString:@"physical"]) {
        status = status | DiskStatusPhysical;
    }
    
    if ([line containsString:@"synthesized"]) {
        status = status | DiskStatusSynthsized;
    }
    
    if ([line containsString:@"disk image"]) {
        status = status | DiskStatusDiskImage;
    }
    
    if ([line containsString:@"external"]) {
        status = status | DiskStatusExternal;
    }
    
    return status;
}

@end
