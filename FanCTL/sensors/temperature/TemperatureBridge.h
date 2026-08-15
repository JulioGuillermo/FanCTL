#ifndef SMCBridge_h
#define SMCBridge_h

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

#define KKERNEL_INDEX_SMC 2

#pragma pack(push, 1)

typedef struct {
    uint8_t  major;
    uint8_t  minor;
    uint8_t  build;
    uint8_t  reserved;
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t  dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t             key;
    SMCKeyData_vers_t    vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    uint8_t              result;
    uint8_t              status;
    uint8_t              data8;
    uint32_t             data32;
    uint8_t              bytes[32];
} SMCParamStruct;

#pragma pack(pop)

enum {
    kSMCSuccess     = 0,
    kSMCError       = 1,
    kSMCKeyNotFound = 0x84
};

enum {
    kSMCCmdReadBytes   = 5,
    kSMCCmdReadIndex   = 8,
    kSMCCmdGetKeyInfo  = 9
};

#endif
