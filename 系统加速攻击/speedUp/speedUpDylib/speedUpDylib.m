//  weibo: http://weibo.com/xiaoqing28
//  blog:  http://www.alonemonkey.com
//
//  speedUpDylib.m
//  speedUpDylib
//
//  Created by 谭建中 on 28/3/2019.
//  Copyright (c) 2019 谭建中. All rights reserved.
//

#import "speedUpDylib.h"
#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <Cycript/Cycript.h>
#import <MDCycriptManager.h>
#import <WXGZ_SDK/WXGZ_SDK.h>

CHConstructor{
    printf(INSERT_SUCCESS_WELCOME);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
  
        //1、初始化SDK
    [MTSS startWithBuryingURL:@"http://172.10.4.152:8888"
                  reportedURL:@"http://172.10.4.152:8080"
                      pushURL:@"http://subscribe.manager.ineice.cn:8080"
                     acceptId:@"4ea0f809ea72dbd5"
                       appKey:@"95961ece59b14a808e92c520a3332012"];
         
        
        
    }];
}


