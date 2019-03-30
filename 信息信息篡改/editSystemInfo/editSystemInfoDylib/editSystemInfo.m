//
//  editSystemInfo.m
//  editSystemInfoDylib
//
//  Created by 谭建中 on 28/3/2019.
//  Copyright © 2019 谭建中. All rights reserved.
//

#import "editSystemInfo.h"
#import "fishhook/fishhook.h"

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <sys/utsname.h>
#include <sys/sysctl.h>

@implementation editSystemInfo

+ (void)load
{
//    通过控制着一行代码的运行和不运行来进行是否基于应用层面的系统信息修改
//    1、第一次启动的时候先不修改系统信息
//    2、第二次启动的时候开启这一行代码
//    [self toHookgettimeofday];
}

int (* origuname)(struct utsname *);
int myuname(struct utsname *uts)
{
    origuname(uts);
    
    char *mod = "_modified";
    //机器名
    strcat(uts->machine, mod);
//    Name of this network node
    strcat(uts->nodename, mod);
    strcat(uts->release, mod);
    strcat(uts->version, mod);
    strcat(uts->sysname, mod);
    
    NSLog(@"============ modify uname func");
    
    return 0;
}


#define MACHINE_NAME "iPhone 12"
int ( *origsysctl)(int *, u_int, void *, size_t *, void *, size_t);
int mysysctl(int *i1, u_int i2, void *obj3, size_t *i4, void *obj5, size_t i6)
{
   int ret = origsysctl(i1, i2, obj3, i4, obj5, i6);
    
    if ((*i1) == 6)
    {
        int sub = *(i1 + 1);
        if (sub == 1) {
            int len = strlen(MACHINE_NAME);
            if(!obj3){
                *i4 = len + 1;
            }
            else{
                memcpy(obj3, MACHINE_NAME, len + 1);
            }
        }
        else if (sub == 3 || sub == 25)//HW_NCPU
        {
            *(int*)(obj3) = 22;
        }
        else if (sub == 5)//HW_PHYSMEM
        {
            *(int*)obj3 = 123321;
        }
        // NSLog(@"------------------sub  %d", sub);
        
    }
    NSLog(@"------------------sysctl 被调用了");
    return ret;
}
+ (void)toHookgettimeofday
{
    //定义rebinding结构体
    struct rebinding nslogBind;
    //函数的名称
    nslogBind.name = "sysctl";
    //新的函数地址
    nslogBind.replacement = mysysctl;
    //保存原始函数地址变量的指针
    nslogBind.replaced = (void *)&origsysctl;
    
    struct rebinding nslogBind2;
    //函数的名称
    nslogBind2.name = "uname";
    //新的函数地址
    nslogBind2.replacement = myuname;
    //保存原始函数地址变量的指针
    nslogBind2.replaced = (void *)&origuname;
    
    //定义数组
    struct rebinding rebs[] = {nslogBind, nslogBind2};
    
    /**
     arg1: 存放rebinding结构体的数组
     arg2: 数组的长度
     */
    rebind_symbols(rebs, 1);
}



@end
