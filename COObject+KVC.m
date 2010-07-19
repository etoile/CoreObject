

#if 0
@implementation COObject (KVC)

- (id) valueForKey:(NSString *)key
{
  [self loadIfNeeded];
  return [_data valueForKey: key];
}

- (void) setValue:(id)value forKey:(NSString*)key
{

}

@end
#endif
