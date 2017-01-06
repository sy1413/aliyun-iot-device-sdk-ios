//
//  Aliyun-MqttClient.h
//  aliyun-iot-device-sdk
//
//  Created by zhuyanshun on 17/1/6.
//  Copyright © 2017年 11. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AliyunMqttClient : NSObject
-(instancetype)initWithProductKey:(NSString*)key productSecret:(NSString*)productSecret deviceName:(NSString*)deviceName deviceSecret:(NSString*)deviceSecret hostName:(NSString*)hostName;
-(void)connectToHost : (void(^)(BOOL status))completionHandler;
-(void)disconnect : (void(^)(BOOL status))completionHandler;

- (void)subscribe:(NSString *)topic withQos:(int)qos completionHandler:(void(^)(BOOL))completionHandler;
- (void)unsubscribe: (NSString *)topic withCompletionHandler:(void (^)(BOOL))completionHandler;

- (void)publishData:(NSString *)payload toTopic:(NSString *)topic withQos:(int)qos retain:(BOOL)retain completionHandler:(void (^)(BOOL))completionHandler;

-(void)messageHandler:(void(^)(NSData* data,NSString* topic))msg;

@end
