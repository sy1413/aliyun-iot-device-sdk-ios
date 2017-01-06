//
//  Aliyun-MqttClient.m
//  aliyun-iot-device-sdk
//
//  Created by zhuyanshun on 17/1/6.
//  Copyright © 2017年 11. All rights reserved.
//

#import "AliyunMqttClient.h"
#include <pthread.h>
#include <unistd.h>
#include "aliyun_iot_mqtt_client.h"
#include "aliyun_iot_auth.h"
#define MSG_LEN_MAX 100

static void (^_newMessageBlock)(NSData* data,NSString* topic);

@interface AliyunMqttClient()
{
    u_char* msg_buf, *msg_readbuf;
    Client client;
}
@end

@implementation AliyunMqttClient
static void messageArrived(MessageData *md)
{
    MQTTMessage *message = md->message;
    if(_newMessageBlock && message->payloadlen){
        
        NSString* topic = @"";
        if(md->topicName->lenstring.data!=NULL){
            topic = [[NSString alloc] initWithBytes:md->topicName->lenstring.data length:md->topicName->lenstring.len encoding:NSUTF8StringEncoding];
        }
        _newMessageBlock([NSData dataWithBytes:message->payload length:message->payloadlen],
                         topic);
    }
}

-(void)messageHandler:(void(^)(NSData* data,NSString* topic))msg
{
    _newMessageBlock = [msg copy];
}

-(instancetype)initWithProductKey:(NSString*)key productSecret:(NSString*)productSecret deviceName:(NSString*)deviceName deviceSecret:(NSString*)deviceSecret hostName:(NSString*)hostName
{
    msg_buf = (unsigned char *)malloc(MSG_LEN_MAX);
    msg_readbuf = (unsigned char *)malloc(MSG_LEN_MAX);
    if(![self initDeviceWithProductKey:key productSecret:productSecret deviceName:deviceName deviceSecret:deviceSecret hostName:hostName]){
        NSLog(@"Aliyun_MqttClient init failed");
    }
    return self;
}

-(BOOL)initDeviceWithProductKey:(NSString*)key productSecret:(NSString*)productSecret deviceName:(NSString*)deviceName deviceSecret:(NSString*)deviceSecret hostName:(NSString*)hostName
{
    if (SUCCESS_RETURN == aliyun_iot_auth_init()){
        IOT_DEVICEINFO_SHADOW_S deviceInfo;
        memset(&deviceInfo, 0x0, sizeof(deviceInfo));
        deviceInfo.productKey = (char*)key.UTF8String;
        deviceInfo.productSecret = (char*)productSecret.UTF8String;
        deviceInfo.deviceName = (char*)deviceName.UTF8String;
        deviceInfo.deviceSecret = (char*)deviceSecret.UTF8String;
        deviceInfo.hostName = (char*)hostName.UTF8String;
        
        if (SUCCESS_RETURN != aliyun_iot_set_device_info(&deviceInfo)){
            return NO;
        }
        
        if (SUCCESS_RETURN != aliyun_iot_auth(HMAC_MD5_SIGN_TYPE, IOT_VALUE_FALSE)){
            return NO;
        }
        return YES;
    }
    return NO;
}

-(void)connectToHost:(void (^)(BOOL))completionHandler
{
    void (^_completionHandler)(BOOL) = [completionHandler copy];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        memset(&client,0x0,sizeof(client));
        
        IOT_CLIENT_INIT_PARAMS initParams;
        memset(&initParams,0x0,sizeof(initParams));
        initParams.mqttCommandTimeout_ms = 2000;
        initParams.pReadBuf = msg_readbuf;
        initParams.readBufSize = MSG_LEN_MAX;
        initParams.pWriteBuf = msg_buf;
        initParams.writeBufSize = MSG_LEN_MAX;
        initParams.disconnectHandler = NULL;
        initParams.disconnectHandlerData = (void*) &client;
        initParams.deliveryCompleteFun = NULL;
        initParams.subAckTimeOutFun = NULL;
        int rc = aliyun_iot_mqtt_init(&client, &initParams);
        if (SUCCESS_RETURN != rc){
            _completionHandler(NO);
            return  ;
        }
        
        MQTTPacket_connectData connectParam;
        memset(&connectParam,0x0,sizeof(connectParam));
        connectParam.cleansession = 1;
        connectParam.MQTTVersion = 4;
        connectParam.keepAliveInterval = 180;
        connectParam.willFlag = 0;
        rc = aliyun_iot_mqtt_connect(&client, &connectParam);
        _completionHandler(SUCCESS_RETURN==rc?YES:NO);
    });
}

-(void)disconnect:(void (^)(BOOL))completionHandler
{
    void (^_completionHandler)(BOOL) = [completionHandler copy];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int rc = aliyun_iot_mqtt_disconnect(&client);
        _completionHandler(SUCCESS_RETURN==rc?YES:NO);
    });
}

- (void)subscribe:(NSString *)topic withQos:(int)qos completionHandler:(void(^)(BOOL))completionHandler
{
    void (^_completionHandler)(BOOL) = [completionHandler copy];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int rc = aliyun_iot_mqtt_subscribe(&client, topic.UTF8String, qos, messageArrived);
        _completionHandler(SUCCESS_RETURN==rc?YES:NO);
    });
}

- (void)unsubscribe: (NSString *)topic withCompletionHandler:(void (^)(BOOL))completionHandler
{
    void (^_completionHandler)(BOOL) = [completionHandler copy];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int rc = aliyun_iot_mqtt_unsubscribe(&client, topic.UTF8String);
        do{
            usleep(10000);
            rc = aliyun_iot_mqtt_unsubscribe(&client, topic.UTF8String);
        }while(rc != SUCCESS_RETURN);
        _completionHandler(SUCCESS_RETURN==rc?YES:NO);
    });
}

- (void)publishData:(NSString *)payload toTopic:(NSString *)topic withQos:(int)qos retain:(BOOL)retain completionHandler:(void (^)(BOOL))completionHandler
{
    void (^_completionHandler)(BOOL) = [completionHandler copy];
    if(client.clientState != CLIENT_STATE_CONNECTED){
        _completionHandler(NO);
        return  ;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        MQTTMessage message;
        memset(&message,0x0,sizeof(message));
        
        char buf[MSG_LEN_MAX] = { 0 };
        sprintf(buf, "{\"message\":\"%s\"}", payload.UTF8String);
        
        message.qos        = qos;
        message.retained   = retain;
        message.dup        = FALSE_IOT;
        message.payload    = (void *) buf;
        message.payloadlen = strlen(buf);
        message.id         = 0;
        
        int rc = aliyun_iot_mqtt_publish(&client, topic.UTF8String, &message);
        do{
            usleep(10000);
            rc = aliyun_iot_mqtt_suback_sync(&client, topic.UTF8String, messageArrived);
        }while(rc != SUCCESS_RETURN);
        _completionHandler(SUCCESS_RETURN==rc?YES:NO);
    });
}

-(void)dealloc
{
    aliyun_iot_mqtt_release(&client);
    _newMessageBlock = nil;
    (void) aliyun_iot_auth_release();
    free(msg_buf);
    free(msg_readbuf);
}
@end
