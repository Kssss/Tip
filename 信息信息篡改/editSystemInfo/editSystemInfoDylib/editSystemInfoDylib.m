//  weibo: http://weibo.com/xiaoqing28
//  blog:  http://www.alonemonkey.com
//
//  editSystemInfoDylib.m
//  editSystemInfoDylib
//
//  Created by 谭建中 on 28/3/2019.
//  Copyright (c) 2019 谭建中. All rights reserved.
//

#import "editSystemInfoDylib.h"
#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <Cycript/Cycript.h>
#import <MDCycriptManager.h>
#include <sys/sysctl.h>
#import <WXGZ_SDK/WXGZ_SDK.h>

int cpuCount1() {
    int mib[2] = { CTL_HW, HW_NCPU };
    unsigned cpuCount;
    size_t sizeOfCpuCount = sizeof(cpuCount);
    int status = sysctl(mib, 2, &cpuCount, &sizeOfCpuCount, NULL, 0);
    if (status == 0) {
        return cpuCount;
    } else {
        return -1;
    }
}


CHConstructor{
    printf(INSERT_SUCCESS_WELCOME);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        
        //1、初始化SDK
        [MTSS startWithBuryingURL:@"http://172.10.4.152:8888"
                      reportedURL:@"http://172.10.4.152:8080"
                          pushURL:@"http://subscribe.manager.ineice.cn:8080"
                         acceptId:@"4ea0f809ea72dbd5"
                           appKey:@"95961ece59b14a808e92c520a3332012"];
        
        
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            int num = cpuCount1();


            NSLog(@"%d",num);

        });  
    }];
}

