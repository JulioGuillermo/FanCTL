#import "PrivilegedExec.h"
@import Security;

static NSString * const kOKMarker = @"FANCTL_OK";

@implementation PrivilegedExec

static NSString * _Nullable gLastError = nil;

+ (nullable NSString *)lastError {
    return gLastError;
}

+ (nullable NSString *)runPrivilegedShellScript:(NSString *)script {
    gLastError = nil;

    AuthorizationRef authRef = NULL;
    OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                          kAuthorizationFlagDefaults, &authRef);
    if (status != errAuthorizationSuccess) {
        gLastError = [NSString stringWithFormat:@"No se pudo inicializar la autenticación (código %d).", (int)status];
        return nil;
    }

    AuthorizationItem right = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &right };
    AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed |
                               kAuthorizationFlagPreAuthorize |
                               kAuthorizationFlagExtendRights;
    status = AuthorizationCopyRights(authRef, &rights, kAuthorizationEmptyEnvironment,
                                     flags, NULL);
    if (status != errAuthorizationSuccess) {
        gLastError = [NSString stringWithFormat:@"Autenticación cancelada o denegada (código %d).", (int)status];
        AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
        return nil;
    }

    char *arguments[] = { "-c", (char *)[script UTF8String], "fanctl-install", NULL };
    FILE *commPipe = NULL;
    status = AuthorizationExecuteWithPrivileges(authRef, "/bin/sh",
                                                kAuthorizationFlagDefaults,
                                                arguments, &commPipe);
    if (status != errAuthorizationSuccess) {
        gLastError = [NSString stringWithFormat:@"No se pudo ejecutar el comando privilegiado (código %d).", (int)status];
        AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
        return nil;
    }

    NSMutableString *collected = [NSMutableString string];
    if (commPipe) {
        char buffer[4096];
        size_t n;
        while ((n = fread(buffer, 1, sizeof(buffer), commPipe)) > 0) {
            [collected appendString:[[NSString alloc] initWithBytes:buffer
                                                             length:n
                                                           encoding:NSUTF8StringEncoding]];
        }
        fclose(commPipe);
    }
    AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);

    if ([collected rangeOfString:kOKMarker].location != NSNotFound) {
        return collected;
    }

    gLastError = collected.length > 0
        ? collected
        : @"El comando de instalación terminó sin éxito.";
    return nil;
}

@end
