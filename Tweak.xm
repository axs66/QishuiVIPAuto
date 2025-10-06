#import <UIKit/UIKit.h>

// 声明外部类
@interface LunaUtils : NSObject
+ (void)sendAPIRequestIncentiveDone:(void (^)(NSError *error, id responseObject))completion;
@end

@interface LunaToast : NSObject
+ (void)showWithMessage:(NSString *)message type:(NSInteger)type;
@end

@interface SchubertIncentiveManager : NSObject
+ (instancetype)sharedInstance;
- (void)sendIncentiveRequest;
- (void)stopPeriodicRequestTimer;
@end

static NSLock *requestLock;

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
                                          type:1];
                } else {
                    NSNumber *statusCode = responseObject[@"status_code"];
                    NSLog(@"[QishuiVIPAuto] ✅ 响应：%@", responseObject);
                    
                    if ([statusCode intValue] == 0) {
                        [LunaToast showWithMessage:@"🎉 畅听权益领取成功" type:0];
                    } else {
                        NSString *statusMsg = responseObject[@"status_info"][@"status_msg"] ?: @"领取失败";
                        [LunaToast showWithMessage:statusMsg type:1];
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

// 在 App 启动后自动触发
%hook AppDelegate
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    NSDate *lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastIncentiveRequestDate"];
    if (![[NSCalendar currentCalendar] isDateInToday:lastDate]) {
        id mgr = [NSClassFromString(@"SchubertIncentiveManager") sharedInstance];
        if ([mgr respondsToSelector:@selector(sendIncentiveRequest)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [mgr performSelector:@selector(sendIncentiveRequest)];
            });
        }
    }
}
%end
