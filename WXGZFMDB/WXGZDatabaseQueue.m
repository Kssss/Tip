//
//  WXGZDatabaseQueue.m
//  DEVdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "WXGZDatabaseQueue.h"
#import "WXGZDatabase.h"
#import "MTSSLog.h"

/*
 
 Note: we call [self retain]; before using dispatch_sync, just incase 
 WXGZDatabaseQueue is released on another thread and we're in the middle of doing
 something in dispatch_sync
 
 */

/*
 * A key used to associate the WXGZDatabaseQueue object with the dispatch_queue_t it uses.
 * This in turn is used for deadlock detection by seeing if inDatabase: is called on
 * the queue's dispatch queue, which should not happen and causes a deadlock.
 */
static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;
 
@implementation WXGZDatabaseQueue

@synthesize path = _path;
@synthesize openFlags = _openFlags;

+ (instancetype)databaseQueueWithPath:(NSString*)aPath {
    
    WXGZDatabaseQueue *q = [[self alloc] initWithPath:aPath];
    
    DEVDBAutorelease(q);
    
    return q;
}

+ (instancetype)databaseQueueWithPath:(NSString*)aPath flags:(int)openFlags {
    
    WXGZDatabaseQueue *q = [[self alloc] initWithPath:aPath flags:openFlags];
    
    DEVDBAutorelease(q);
    
    return q;
}

+ (Class)databaseClass {
    return [WXGZDatabase class];
}

- (instancetype)initWithPath:(NSString*)aPath flags:(int)openFlags {
    
    self = [super init];
    
    if (self != nil) {
        
        _db = [[[self class] databaseClass] databaseWithPath:aPath];
        DEVDBRetain(_db);
        
#if SQLITE_VERSION_NUMBER >= 3005000
        BOOL success = [_db openWithFlags:openFlags];
#else
        BOOL success = [_db open];
#endif
        if (!success) {
            MTSSLog(@"Could not create database queue for path %@", aPath);
            DEVDBRelease(self);
            return 0x00;
        }
        
        _path = DEVDBReturnRetained(aPath);
        
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"DEVdb.%@", self] UTF8String], NULL);
        dispatch_queue_set_specific(_queue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        _openFlags = openFlags;
    }
    
    return self;
}

- (instancetype)initWithPath:(NSString*)aPath {
    
    // default flags for sqlite3_open
    return [self initWithPath:aPath flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
}

- (instancetype)init {
    return [self initWithPath:nil];
}

    
- (void)dealloc {
    
    DEVDBRelease(_db);
    DEVDBRelease(_path);
    
    if (_queue) {
        DEVDBDispatchQueueRelease(_queue);
        _queue = 0x00;
    }
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)close {
    DEVDBRetain(self);
    dispatch_sync(_queue, ^() {
        [self->_db close];
        DEVDBRelease(_db);
        self->_db = 0x00;
    });
    DEVDBRelease(self);
}

- (WXGZDatabase*)database {
    if (!_db) {
        _db = DEVDBReturnRetained([WXGZDatabase databaseWithPath:_path]);
        
#if SQLITE_VERSION_NUMBER >= 3005000
        BOOL success = [_db openWithFlags:_openFlags];
#else
        BOOL success = [_db open];
#endif
        if (!success) {
            MTSSLog(@"WXGZDatabaseQueue could not reopen database for path %@", _path);
            DEVDBRelease(_db);
            _db  = 0x00;
            return 0x00;
        }
    }
    
    return _db;
}

- (void)inDatabase:(void (^)(WXGZDatabase *db))block {
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    WXGZDatabaseQueue *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "inDatabase: was called reentrantly on the same queue, which would lead to a deadlock");
    
    DEVDBRetain(self);
    
    dispatch_sync(_queue, ^() {
        
        WXGZDatabase *db = [self database];
        block(db);
        
        if ([db hasOpenResultSets]) {
            MTSSLog(@"Warning: there is at least one open result set around after performing [WXGZDatabaseQueue inDatabase:]");
            
#if defined(DEBUG) && DEBUG
            NSSet *openSetCopy = DEVDBReturnAutoreleased([[db valueForKey:@"_openResultSets"] copy]);
            for (NSValue *rsInWrappedInATastyValueMeal in openSetCopy) {
                WXGZResultSet *rs = (WXGZResultSet *)[rsInWrappedInATastyValueMeal pointerValue];
                MTSSLog(@"query: '%@'", [rs query]);
            }
#endif
        }
    });
    
    DEVDBRelease(self);
}


- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(WXGZDatabase *db, BOOL *rollback))block {
    DEVDBRetain(self);
    dispatch_sync(_queue, ^() { 
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            [[self database] beginDeferredTransaction];
        }
        else {
            [[self database] beginTransaction];
        }
        
        block([self database], &shouldRollback);
        
        if (shouldRollback) {
            [[self database] rollback];
        }
        else {
            [[self database] commit];
        }
    });
    
    DEVDBRelease(self);
}

- (void)inDeferredTransaction:(void (^)(WXGZDatabase *db, BOOL *rollback))block {
    [self beginTransaction:YES withBlock:block];
}

- (void)inTransaction:(void (^)(WXGZDatabase *db, BOOL *rollback))block {
    [self beginTransaction:NO withBlock:block];
}

#if SQLITE_VERSION_NUMBER >= 3007000
- (NSError*)inSavePoint:(void (^)(WXGZDatabase *db, BOOL *rollback))block {
    
    static unsigned long savePointIdx = 0;
    __block NSError *err = 0x00;
    DEVDBRetain(self);
    dispatch_sync(_queue, ^() { 
        
        NSString *name = [NSString stringWithFormat:@"savePoint%ld", savePointIdx++];
        
        BOOL shouldRollback = NO;
        
        if ([[self database] startSavePointWithName:name error:&err]) {
            
            block([self database], &shouldRollback);
            
            if (shouldRollback) {
                // We need to rollback and release this savepoint to remove it
                [[self database] rollbackToSavePointWithName:name error:&err];
            }
            [[self database] releaseSavePointWithName:name error:&err];
            
        }
    });
    DEVDBRelease(self);
    return err;
}
#endif

@end
