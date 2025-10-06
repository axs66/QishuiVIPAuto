#import <UIKit/UIKit.h>

// 声明外部类
typedef NS_ENUM(NSInteger, LunaToastType) {
    LunaToastTypeSuccess = 0,
    LunaToastTypeError = 1,
    LunaToastTypeInfo = 2,
};
@interface LunaUtils : NSObject
+ (void)sendAPIRequestIncentiveDone:(void (^)(NSError *error, id responseObject))completion;
@end

@interface LunaToast : NSObject
+ (void)showWithMessage:(NSString *)message type:(LunaToastType)type;
@end

@interface SchubertIncentiveManager : NSObject
+ (instancetype)sharedInstance;
- (void)sendIncentiveRequest;
- (void)stopPeriodicRequestTimer;
@end

static NSLock *requestLock;
static BOOL hasScheduledTodayRequest = NO;

static BOOL QishuiVIPAuto_IsRequestedToday(void) {
    NSDate *lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastIncentiveRequestDate"];
    if (!lastDate) return NO;
    return [[NSCalendar currentCalendar] isDateInToday:lastDate];
}

static void QishuiVIPAuto_ScheduleRequestIfNeeded(void) {
    if (QishuiVIPAuto_IsRequestedToday()) {
        NSLog(@"[QishuiVIPAuto] ⏭ 今日已领取，跳过");
        return;
    }

    if (!requestLock) requestLock = [[NSLock alloc] init];

    if (hasScheduledTodayRequest) {
        NSLog(@"[QishuiVIPAuto] ⏭ 已安排本次会话的领取请求，去抖");
        return;
    }

    hasScheduledTodayRequest = YES;

    id mgr = [NSClassFromString(@"SchubertIncentiveManager") sharedInstance];
    if ([mgr respondsToSelector:@selector(sendIncentiveRequest)]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hasScheduledTodayRequest = NO;
            [mgr performSelector:@selector(sendIncentiveRequest)];
        });
        NSLog(@"[QishuiVIPAuto] ⏳ 已安排 15 秒后发送领取请求");
    } else {
        hasScheduledTodayRequest = NO;
        NSLog(@"[QishuiVIPAuto] ⚠️ 未找到 SchubertIncentiveManager.sendIncentiveRequest");
    }
}

// Hook 主类，自动执行领取逻辑
%hook SchubertIncentiveManager

- (void)sendIncentiveRequest {
    if (!requestLock) requestLock = [[NSLock alloc] init];
    
    if ([requestLock tryLock]) {
        @try {
            NSLog(@"[QishuiVIPAuto] 🚀 开始发送畅听权益请求...");
            
            [LunaUtils sendAPIRequestIncentiveDone:^(NSError *error, id responseObject) {
                if (error) {
                    NSLog(@"[QishuiVIPAuto] ❌ 请求失败：%@", error);
                    [LunaToast showWithMessage:[NSString stringWithFormat:@"网络错误：%@", error.localizedDescription]
                                          type:LunaToastTypeError];
                } else {
                    if (![responseObject isKindOfClass:[NSDictionary class]]) {
                        NSLog(@"[QishuiVIPAuto] ⚠️ 非预期响应：%@", responseObject);
                        [LunaToast showWithMessage:@"服务响应异常" type:LunaToastTypeError];
                        return;
                    }

                    NSNumber *statusCode = ((NSDictionary *)responseObject)[@"status_code"];
                    NSLog(@"[QishuiVIPAuto] ✅ 响应：%@", responseObject);
                    
                    if ([statusCode intValue] == 0) {
                        [LunaToast showWithMessage:@"🎉 畅听权益领取成功" type:LunaToastTypeSuccess];
                    } else {
                        NSString *statusMsg = ((NSDictionary *)responseObject)[@"status_info"][@"status_msg"] ?: @"领取失败";
                        [LunaToast showWithMessage:statusMsg type:LunaToastTypeError];
                    }

                    if ([self respondsToSelector:@selector(stopPeriodicRequestTimer)]) {
                        [self stopPeriodicRequestTimer];
                    }

                    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date]
                                                              forKey:@"LastIncentiveRequestDate"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }];
        }
        @catch (NSException *exception) {
            NSLog(@"[QishuiVIPAuto] ⚠️ 异常：%@", exception);
        }
        @finally {
            [requestLock unlock];
        }
    } else {
        NSLog(@"[QishuiVIPAuto] 🔒 请求被锁定，跳过本次执行");
    }
}

%end

// 通过前台激活通知触发，更通用且避免侵入 AppDelegate
%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification * _Nonnull note) {
            QishuiVIPAuto_ScheduleRequestIfNeeded();
        }];
    }
}
