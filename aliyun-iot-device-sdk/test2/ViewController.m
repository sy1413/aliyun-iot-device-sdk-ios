//
//  ViewController.m
//  test2
//
//  Created by 11 on 17/1/5.
//  Copyright © 2017年 11. All rights reserved.
//

#import "ViewController.h"

#include <pthread.h>
#include <unistd.h>
#include "aliyun_iot_mqtt_client.h"
#include "aliyun_iot_auth.h"

#define HOST_NAME      @"iot.channel.aliyun.com"
#define PRODUCT_KEY    @"1000074263"
#define PRODUCT_SECRET @"DiKBI7ZoxZrussV3"
#define DEVICE_NAME    @"E-Link"
#define DEVICE_SECRET  @"6iykYMhLrN0hZujE"

#define TOPIC          @"/1000074263/test3"
#define TOPIC2         @"/1000074263/test2"

#define MSG_LEN_MAX 100

#import "AliyunMqttClient.h"

@interface ViewController ()
@property (nonatomic,strong) AliyunMqttClient *client;
@end

@implementation ViewController

-(void)viewDidLoad
{
    _client = [[AliyunMqttClient alloc] initWithProductKey:PRODUCT_KEY productSecret:PRODUCT_SECRET deviceName:DEVICE_NAME deviceSecret:DEVICE_SECRET hostName:HOST_NAME];
    [_client messageHandler:^(NSData *data, NSString *topic) {
        NSLog(@"message: %@ - %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], topic);
    }];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [_client connectToHost:^(BOOL status) {
        if(status){
            [_client subscribe:TOPIC withQos:1 completionHandler:^(BOOL status) {
                 if(status) NSLog(@"订阅成功");
            }];
        }
    }];
}
@end
