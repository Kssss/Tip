//
//  speedUp.m
//  speedUpDylib
//
//  Created by 谭建中 on 28/3/2019.
//  Copyright © 2019 谭建中. All rights reserved.
//
#import "speedup2.h"
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#import "fishhook/fishhook.h"

@implementation speedup2
+ (void)load
{
    [self toHookgettimeofday];
}

#define SPEEDLEVEL 10
static int (*orig_gettimeofday)(struct timeval * __restrict, void * __restrict);
int mygettimeofday(struct timeval * tv, void * tz)
{
    int ret = orig_gettimeofday(tv,tz);
    if (ret == 0) {
        if(tv->tv_sec && tv->tv_usec) {
            tv->tv_usec *= SPEEDLEVEL;
            tv->tv_sec *= SPEEDLEVEL;
        }
    }
    
    return ret;
}

+ (void)toHookgettimeofday
{
    //定义rebinding结构体
    struct rebinding nslogBind;
    //函数的名称
    nslogBind.name = "gettimeofday";
    //新的函数地址
    nslogBind.replacement = mygettimeofday;
    //保存原始函数地址变量的指针
    nslogBind.replaced = (void *)&orig_gettimeofday;
    
    //定义数组
    struct rebinding rebs[] = {nslogBind};
    
    /**
     arg1: 存放rebinding结构体的数组
     arg2: 数组的长度
     */
    rebind_symbols(rebs, 1);
}

@end

