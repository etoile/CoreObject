#import <Foundation/Foundation.h>

/**
 * COSynchronizer is a tool responsible for:
 * - live collaboration
 * - offline collaboration
 *
 * How should the synchronizer interact with branches? Ideally, mindful of them.
 * For example, if syncing two computers, you want the branches copied over.
 *
 * If someone does a revert to a old revision, everyone should get it? maybe not.
 * 
 
Use case:
 
 
problems:
 
 // Collect UUIDS of all objects changed AFTER the shadow node and before or on the baseHistoryGraphNode
 ----> is this hard in om2?
 shouldn't be.
 
 */
@interface COSynchronizer : NSObject
{

}

@end
