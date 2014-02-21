
+ (NSUInteger) sizeOfPath: (NSString *)aPath
{
    NSUInteger result = 0;
    for (NSString *subpath in [[NSFileManager defaultManager] subpathsAtPath: aPath])
    {
		NSError *error = nil;
        NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath: [aPath stringByAppendingPathComponent: subpath] error: &error];
		assert(attribs != nil && error == nil);
        result += [[attribs objectForKey: NSFileSize] longLongValue];
    }
    return result;
}
