//
//  DyQQMsgObserverItem.m
//  DyInjectService
//
//  Created by Shawn on 2017/1/20.
//  Copyright © 2017年 Shawn. All rights reserved.
//

#import "DyQQMsgObserverItem.h"
#import <UIKit/UIKit.h>

typedef void (^CDUnknownBlockType)(void);

@interface NSObject (MethodInterface)

#pragma mark - QQ Model

- (int)msgType;

- (NSString *)content;

- (NSString *)uin;

- (BOOL)isGroupMsg;

#pragma mark account model

+ (id)getInstance;

- (id)currentModel;

- (NSString *)getLoginNickname;

- (id)getSig_SKEYStr;

- (long long)getUin;

#pragma mark - wallet

- (void)gotoTenpayView:(id)arg1 rootVC:(id)arg2 params:(id)arg3 completion:(CDUnknownBlockType)arg4;

+ (id)GetInstance;

#pragma chat vc

- (id)initWithuin:(id)arg1 isGroup:(_Bool)arg2;

@end

@interface DyQQMsgObserverItem ()
{
    UIViewController * vc ;
}
@end

@implementation DyQQMsgObserverItem

static DyQQMsgObserverItem * observerItem = nil;

+ (void)load
{
    observerItem = [DyQQMsgObserverItem new];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(_didReceiverMsg:) name:@"__QQAddressBookAppGetMessageNotification__" object:nil];
    }
    return self;
}

- (void)_didReceiverMsg:(NSNotification *)not
{
    NSLog(@"_didReceiverMsg %@",[not object]);
    id msgModel = [not object];
    if ([msgModel isKindOfClass:[NSArray class]]) {
        for (id tempMsgModel in msgModel) {
            [self _openRedPacketWithMsgModel:tempMsgModel];
        }
    }else
        [self _openRedPacketWithMsgModel:msgModel];
}

- (void)_openRedPacketWithMsgModel:(id)msgModel
{
    if ([msgModel isKindOfClass:NSClassFromString(@"QQMessageModel")] == NO) {
        return;
    }
    
    if ([msgModel msgType] != 311) {
        return;
    }
    NSString * content = [msgModel content];
    NSData * jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) {
        return;
    }
    NSDictionary * contentDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
    if (!contentDic) {
        return;
    }
    NSString * authKey = contentDic[@"authkey"];
    NSString * redPacketId = contentDic[@"billno"];
    
    id accountService = [NSClassFromString(@"QAccountService") getInstance];
    long long loginUin = [accountService getUin];
    NSString * skey = [accountService getSig_SKEYStr];
    if (skey.length == 0) {
        // skey 没取到 可能是 QQWallect 的信息还没有获取 延迟处理这个红包
        dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
        
        dispatch_after(time, dispatch_get_main_queue(), ^{
            
            [self _openRedPacketWithMsgModel:msgModel];
        });
        
        return;
    }
    
    NSString * loginUserUin = [NSString stringWithFormat:@"%@",[NSNumber numberWithLongLong:loginUin]];
    
    NSMutableDictionary * tempDic = [NSMutableDictionary dictionary];
    [tempDic setValue:@"appid#1344242394|bargainor_id#1000030201|channel#msg" forKey:@"app_info"];
    [tempDic setValue:@"2" forKey:@"come_from"];
    [tempDic setValue:loginUserUin forKey:@"userId"];
    if ([msgModel isGroupMsg]) {
        [tempDic setValue:@"1" forKey:@"grouptype"];
        [tempDic setValue:[NSString stringWithFormat:@"%@",[msgModel valueForKey:@"_groupCode"]] forKey:@"groupid"];
    }else
    {
        [tempDic setValue:loginUserUin forKey:@"groupid"];
        [tempDic setValue:@"0" forKey:@"grouptype"];//如果是群消息 就为 1
    }
    
    NSMutableDictionary * extraDic = [NSMutableDictionary dictionary];
    [extraDic setValue:@"" forKey:@"answer"];
    [extraDic setValue:authKey forKey:@"authkey"];
    [extraDic setValue:redPacketId forKey:@"listid"];
    [extraDic setValue:[accountService getLoginNickname] forKey:@"name"];
    [extraDic setValue:skey forKey:@"skey"];
    [extraDic setValue:@"2" forKey:@"skey_type"];
    
    NSMutableDictionary * detailInfo = [NSMutableDictionary dictionary];
    [detailInfo setValue:@"1" forKey:@"channel"];
    [extraDic setValue:detailInfo forKey:@"detailinfo"];
    
    [tempDic setValue:extraDic forKey:@"extra_data"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Class wallect =NSClassFromString(@"QQWallet");
        UINavigationController * nai = [[NSClassFromString(@"QQNavigationController") alloc]init];
        vc = nai;
        [[wallect GetInstance]gotoTenpayView:@"graphb" rootVC:nai params:tempDic completion:nil];
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"__QQAddressBookAppGetMessageNotification__" object:nil];
}

@end
