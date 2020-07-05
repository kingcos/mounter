//
//  DiskManager.h
//  MyHouseMyRule
//
//  Created by kingcos on 2020/7/5.
//  Copyright © 2020 leave. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, DiskStatus) {
    DiskStatusNone            = 0,
    DiskStatusInternal        = 1 << 0,
    DiskStatusPhysical        = 1 << 1,
    DiskStatusSynthsized      = 1 << 2,
    DiskStatusDiskImage       = 1 << 3,
    DiskStatusExternal        = 1 << 4,
};

typedef NS_ENUM(NSUInteger, DiskPartitionType) {
    DiskPartitionTypeUnknown,
    DiskPartitionTypeEFI,
};

#pragma mark - DiskModel
@interface DiskModel : NSObject

/// ID
@property (nonatomic, copy, readonly) NSString *id;
/// 状态
@property (nonatomic, assign, readonly) DiskStatus status;
/// 分区类型
@property (nonatomic, assign, readonly) DiskPartitionType partitionType;

/// 是否可装载
- (BOOL)isMountable;

/// 是否已装载
- (BOOL)isMounted;

/// 是否为整磁盘（非分区）
- (BOOL)isWhole;

@end

#pragma mark - DiskManager
@interface DiskManager : NSObject

/// 所有磁盘分区
+ (NSArray<DiskModel *> *)list;

/// 根据 ID 寻找对应磁盘信息
+ (DiskModel *)diskModelByID:(nonnull NSString *)id;

/// 装载磁盘分区
+ (void)mountByID:(NSString *)id completion:(nullable void(^)(NSError * _Nullable error))completion;
/// 推出磁盘分区
+ (void)unmountByID:(NSString *)id completion:(nullable void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
