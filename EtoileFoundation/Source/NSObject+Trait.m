#define DEFINE_STRINGS
#import "NSObject+Trait.h"
#undef DEFINE_STRINGS
#import "ETCollection.h"
#import "ETCollection+HOM.h"
#import "Macros.h"
#import "EtoileCompatibility.h"
#include <objc/runtime.h>

static inline BOOL validateMethodTypes(Method method1, Method method2)
{
	return (strcmp(method_getTypeEncoding(method1), method_getTypeEncoding(method2)) == 0);
}

static inline Method findMethod(Method method, Class aClass, BOOL searchSuper)
{
	const char *selectorName = sel_getName(method_getName(method));
	Class class = aClass;

	while (class != Nil)
	{
		unsigned int methodCount = 0;
		Method *methods = class_copyMethodList(class, &methodCount);

		for (unsigned int i = 0; i < methodCount; i++)
		{
			SEL selectorInUse = method_getName(methods[i]);
			// NOTE: We don't check selector equality, in case multiple 
			// selectors whose type encodings vary, use the same name.
			// For example, if we compare (BOOL)bla vs (id)bla, then the later 
			// is returned and it's the responsability of the caller to validate 
			// method equality based on their type encoding. 
			if(strcmp(selectorName, sel_getName(selectorInUse)) == 0)
			{
				free(methods);
				return class_getInstanceMethod(class, selectorInUse);;
			}
		}
		free(methods);

		class = (searchSuper ? class_getSuperclass(class) : Nil);
	}

	return NULL;
}

static inline BOOL methodTypesMatch(Class aClass, Class aMixin)
{
	unsigned int methodCount = 0;
	Method *methods = class_copyMethodList(aMixin, &methodCount);

	for (unsigned int i = 0; i < methodCount; i++)
	{
		Method newMethod = methods[i];
		Method oldMethod = findMethod(newMethod, aClass, YES);

		/* If there is an existing method with this name, check the types match */
		if (oldMethod != NULL && validateMethodTypes(oldMethod, newMethod) == NO)
		{
			free(methods);
			return NO;
		}
	}
	free(methods);

	return YES;
}

static inline BOOL validateIvarTypes(Ivar ivar1, Ivar ivar2)
{
	return (strcmp(ivar_getTypeEncoding(ivar1), ivar_getTypeEncoding(ivar2)) == 0);
}

static inline BOOL iVarTypesMatch(Class aClass, Class aTrait)
{
	unsigned int traitIvarCount = 0;
	Ivar *traitIvars = class_copyIvarList(aTrait, &traitIvarCount);
	unsigned int classIvarCount = 0;
	Ivar *classIvars = class_copyIvarList(aTrait, &classIvarCount);

	if (traitIvars != NULL && classIvars != NULL && traitIvarCount <= classIvarCount)
	{
		/* Look at each ivar in the trait */
		for (unsigned int i = 0; i < traitIvarCount; i++)
		{
			/* If the trait has ivars of a different type to the class */
			if (validateIvarTypes(traitIvars[i], classIvars[i]) == NO)
			{
				free(traitIvars);
				free(classIvars);
				return NO;
			}
		}
	}
	free(traitIvars);
	free(classIvars);

	return YES;
}

static inline void replaceMethodWithMethod(Class aClass, Method aMethod, const char *customMethodName)
{
	SEL selector = method_getName(aMethod);
	IMP imp = method_getImplementation(aMethod);
	const char *typeEncoding = method_getTypeEncoding(aMethod);

	if (customMethodName != NULL)
	{
		selector = sel_registerName(customMethodName);
	}

	class_replaceMethod(aClass, selector, imp, typeEncoding);
}

static void checkSafeComposition(Class class, Class appliedClass)
{
	/* Check that the trait will never try to access ivars from after the end of the object */
	if (class_getInstanceSize(class) < class_getInstanceSize(appliedClass))
	{
		[NSException raise: ETTraitInvalidSizeException
		            format: @"Class %@ has a smaller instance size than trait %@. "
		                     "Either the instance variable count or types do not match. "
		                     "Instance variables access from trait is unsafe.", 
		                    class, appliedClass];
	}
	if (!iVarTypesMatch(class, appliedClass))
	{
		[NSException raise: ETTraitIVarTypeMismatchException
		            format: @"Instance variable types of class %@ do not match those of trait %@. "
		                     "Instance variables access from trait is unsafe.", 
		                    class, appliedClass];
	}
	if (!methodTypesMatch(class, appliedClass))
	{
		[NSException raise: ETTraitMethodTypeMismatchException
		            format: @"Method types of class %@ do not match those of trait %@.", 
		                    class, appliedClass];
	}
}

static NSMutableSet *methodNamesForClass(Class aClass)
{
	unsigned int methodCount;
	Method *methods = class_copyMethodList(aClass, &methodCount);
	NSMutableSet *methodNames = [NSMutableSet setWithCapacity: methodCount];

	for (int i = 0; i < methodCount; i++)
	{
		const char *name = sel_getName(method_getName(methods[i]));
		[methodNames addObject: [NSString stringWithUTF8String: name]];
	}
	free(methods);

	return methodNames;
}

@interface NSObject (Private)
+ (NSMutableArray *) traitApplications;
@end

@interface ETTraitApplication : NSObject
{
	@private
	Class trait;
	NSSet *excludedMethodNames;
	NSDictionary *aliasedMethodNames;
	NSMutableSet *skippedMethodNames;
	NSMutableDictionary *overridenMethods;
}

@property (retain, nonatomic) Class trait;
@property (retain, nonatomic) NSSet *excludedMethodNames;
@property (retain, nonatomic) NSDictionary *aliasedMethodNames;
@property (readonly, nonatomic) NSMutableSet *skippedMethodNames;
@property (readonly, nonatomic) NSSet *initialMethodNames;
@property (readonly, nonatomic) NSSet *allMethodNames;
@property (readonly, nonatomic) NSSet *appliedMethodNames;

/* Trait Extensions related to Mixin-style Composition */

@property (readonly, nonatomic) NSMutableDictionary *overridenMethods;
- (void) setOverridenMethodNames: (NSSet *)methodNames;
@property (readonly, nonatomic) NSSet *appliedOverridenMethodNames;

@end

@implementation ETTraitApplication

@synthesize trait, excludedMethodNames, aliasedMethodNames, skippedMethodNames, overridenMethods;

/* Initializes and returns a trait application that represents how the given 
trait class is going to be applied to a target class. */
- (id) initWithTrait: (Class)aTrait
{
	SUPERINIT;
	ASSIGN(trait, aTrait);
	excludedMethodNames = [[NSSet alloc] init];
	aliasedMethodNames = [[NSDictionary alloc] init];
	skippedMethodNames = [[NSMutableSet alloc] init];
	// NOTE: Could be used once we require Clang 3.0. 
	// With Clang 2.9, -[NSConcretePointerFunctions initWithOptions:] receive corrupted args
	//ASSIGN(overridenMethods, [NSMapTable mapTableWithKeyOptions: NSMapTableStrongMemory
	//                                               valueOptions: NSPointerFunctionsOpaqueMemory]);
	overridenMethods = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(trait);
	DESTROY(excludedMethodNames);
	DESTROY(aliasedMethodNames);
	DESTROY(skippedMethodNames);
	DESTROY(overridenMethods);
	[super dealloc];
}

/* Returns the local trait methods, not including subtrait methods if the 
trait class is a composite.

Methods that belong to the trait superclass are not included.

No aliasing or exclusion is visible in the returned methods. */
- (NSSet *) initialMethodNames
{
	NSMutableSet *methodNames = methodNamesForClass(trait);

	for (ETTraitApplication *traitApp in [trait traitApplications])
	{
		[methodNames minusSet: [traitApp appliedMethodNames]];
	}

	return methodNames;
}

/* Returns both local trait methods and subtrait methods.

Methods that belong to the trait superclass are not included.

No aliasing or exclusion is visible in the returned methods. */
- (NSSet *) allMethodNames
{
	return methodNamesForClass(trait);
}

/* Returns the methods that initially don't belong to the trait class, but 
were added by applying traits (known as subtraits in such case) to the trait 
class.

Returns an empty set when the trait is not composite trait (i.e. no 
subtraits). */
- (NSSet *) subtraitMethodNames
{
	NSMutableSet *methodNames = [NSMutableSet set];

	for (ETTraitApplication *traitApp in [trait traitApplications])
	{
		[methodNames unionSet: [traitApp appliedMethodNames]];
	}

	return methodNames;
}

- (NSSet *) appliedMethodNamesForNames: (NSSet *)rawMethodNames
{
	NSMutableSet *methodNames = [NSMutableSet set];

	for (NSString *name in rawMethodNames)
	{
		if ([excludedMethodNames containsObject: name])
			continue;

		NSString *aliasedName = [aliasedMethodNames objectForKey: name];

		[methodNames addObject: (aliasedName != nil ? aliasedName : name)];
	}

	return methodNames;
}

/* Returns the methods to be added to the target class.

The returned methods are the union of the local trait methods and the subtrait 
methods, and also include methods overriden by the target class.

Local methods provided by -methodNames can appear excluded and/or aliased in 
the returned set. */
- (NSSet *) appliedMethodNames
{
	return [self appliedMethodNamesForNames: [self allMethodNames]];
}

/* Declares the methods which should be overriden in the target class by 
trait provided methods.

-setAliasedMethodNames: must be called before this method.

Method IMPs must be later inserted with -overridenMethods. When this method 
returns, -overridenMethods only contains method names as keys but no IMP as values. */
- (void) setOverridenMethodNames: (NSSet *)methodNames
{
	for (NSString *name in methodNames)
	{
		NSString *aliasedName = [aliasedMethodNames objectForKey: name];

		[overridenMethods setObject: [NSNull null] 
		                     forKey: (aliasedName != nil ? aliasedName : name)
];
	}
}

/* Returns the methods to be overriden in the target class.

The returned method names are keys in -overridenMethods.

Local methods provided by -methodNames can appear aliased in the returned set, 
but no exclusion is visible. */
- (NSSet *) appliedOverridenMethodNames
{
	return [self appliedMethodNamesForNames: 
		[NSSet setWithArray: [[overridenMethods keyEnumerator] allObjects]]];
}

/* Returns the trait application in which the given method name is declared.

The returned trait can be the receiver, a subtrait or nil if no such method 
can be found in the subtrait tree. */
- (ETTraitApplication *) subtraitApplicationForMethodName: (NSString *)aName
{
	if ([[self initialMethodNames] containsObject: aName])
		return self;

	ETTraitApplication *matchedSubtraitApp = nil;

	for (ETTraitApplication *traitApp in [trait traitApplications])
	{
		matchedSubtraitApp = [traitApp subtraitApplicationForMethodName: aName];

		if (matchedSubtraitApp != nil)
			break;
	}

	return matchedSubtraitApp;
}

@end

static void applyTrait(Class class, ETTraitApplication *aTraitApplication)
{
	NSSet *traitMethodNames = [aTraitApplication appliedMethodNames];
	NSSet *excludedNames = [aTraitApplication excludedMethodNames];
	NSDictionary *aliasedNames = [aTraitApplication aliasedMethodNames];
	NSSet *overridenMethodNames = [aTraitApplication appliedOverridenMethodNames];
	unsigned int methodCount = 0;
	Method *methods = class_copyMethodList([aTraitApplication trait], &methodCount);

	for (unsigned int i = 0; i < methodCount; i++)
	{
		NSString *methodName = [NSString stringWithUTF8String: sel_getName(method_getName(methods[i]))];

		if ([traitMethodNames containsObject: methodName] == NO)
		{
			/* A trait method can be excluded */
			if ([excludedNames containsObject: methodName])
					continue;

			/* A trait method can be aliased */
			methodName = [aliasedNames objectForKey: methodName];
			assert(methodName != nil);
		}

		/* A trait method cannot override a method in the target class */
		if (findMethod(methods[i], class, NO) == NULL)
		{
			replaceMethodWithMethod(class, methods[i], [methodName UTF8String]);
		}
		else
		{
			/* Unless mixin-style composition has been requested */
			if ([overridenMethodNames containsObject: methodName])
			{
				Method method = class_getInstanceMethod(class, method_getName(methods[i]));
				NSValue *imp = [NSValue valueWithPointer: (id)method_getImplementation(method)];
				[[aTraitApplication overridenMethods] setObject: imp 
				                                         forKey: methodName];

				replaceMethodWithMethod(class, methods[i], [methodName UTF8String]);	
			}
			else
			{
				/* Memorize each trait method overriden by the target class */
				[[aTraitApplication skippedMethodNames] addObject: methodName];
			}
		}
	}
	free(methods);
}

static NSSet *redundantSubtraitMethodNames(NSSet *methodNames, ETTraitApplication *traitApp1, ETTraitApplication *traitApp2)
{
	NSMutableSet *redundantMethodNames = [NSMutableSet set];

	for (NSString *name in methodNames)
	{
		ETTraitApplication *subtraitApp1 = [traitApp1 subtraitApplicationForMethodName: name];
		ETTraitApplication *subtraitApp2 = [traitApp2 subtraitApplicationForMethodName: name];
		BOOL methodFromSameSubtraitClass = (subtraitApp1 != traitApp1 && subtraitApp2 != traitApp2
		 && [[subtraitApp1 trait] isEqual: [subtraitApp2 trait]]);
		
		if (methodFromSameSubtraitClass)
		{
			[redundantMethodNames addObject: name];
		}
	}

	return redundantMethodNames;
}

static void checkTraitApplication(Class aClass, ETTraitApplication *aTraitApplication)
{
	NSSet *traitMethodNames = [aTraitApplication appliedMethodNames];
	NSSet *traitOverridenMethodNames = [aTraitApplication appliedOverridenMethodNames];
	NSMutableSet *allSkippedMethodNames = [NSMutableSet set];

	/* Collect all existing trait methods overriden by the target class */

	for (ETTraitApplication *traitApp in [aClass traitApplications])
	{
		[allSkippedMethodNames unionSet: [traitApp skippedMethodNames]];
	}

	/* Find method conflicts between new trait and every trait previously applied */

	for (ETTraitApplication *traitApp in [aClass traitApplications])
	{
		NSSet *methodNames = [traitApp appliedMethodNames];

		if ([traitMethodNames intersectsSet: methodNames])
		{
			NSMutableSet *conflictingMethodNames = [NSMutableSet setWithSet: methodNames];

			[conflictingMethodNames intersectSet: traitMethodNames];
			[conflictingMethodNames minusSet: 
				redundantSubtraitMethodNames(conflictingMethodNames, aTraitApplication, traitApp)];
			/* When a trait method is overriden by the target class, the conflict 
			   is implicitly resolved */
			[conflictingMethodNames minusSet: allSkippedMethodNames];

			/* When a method is declared as to be overriden by the trait method, the 
			   conflict is also implicitly resolved

			   The method to be overriden originates either from:
			   - the target class
			   - a trait previously applied to the target class. */
			[conflictingMethodNames minusSet: traitOverridenMethodNames];

			if ([conflictingMethodNames isEmpty])
				continue;

			[NSException raise: ETTraitApplicationException
			            format: @"Trait methods %@ from %@ already exist in trait %@ previously applied to class %@.", 
			                    conflictingMethodNames, [aTraitApplication trait], [traitApp trait], aClass];
		}
	}
}

@implementation NSObject (Trait)

static NSMapTable *traitApplicationsByClass = nil;
static NSRecursiveLock *lock = nil;

+ (void) load
{
	ASSIGN(traitApplicationsByClass, [NSMapTable mapTableWithWeakToStrongObjects]);
	lock = [[NSRecursiveLock alloc] init];
}

+ (NSMutableArray *) traitApplications
{
	[lock lock];

	NSMutableArray *traitApplications = [traitApplicationsByClass objectForKey: self];

	if (traitApplications == nil)
	{
		traitApplications = [NSMutableArray array];
		[traitApplicationsByClass setObject: traitApplications forKey: self];
	}

	[lock unlock];

	return traitApplications;
}

+ (void) applyTraitFromClass: (Class)aClass 
         excludedMethodNames: (NSSet *)excludedNames
          aliasedMethodNames: (NSDictionary *)aliasedNames
        overridenMethodNames: (NSSet *)overridenNames
{
	[lock lock];

 	ETTraitApplication *traitApplication = AUTORELEASE([[ETTraitApplication alloc] initWithTrait: aClass]);

	[traitApplication setExcludedMethodNames: excludedNames];
	[traitApplication setAliasedMethodNames: aliasedNames];
	[traitApplication setOverridenMethodNames: overridenNames];

	checkSafeComposition(self, aClass);
	checkTraitApplication(self, traitApplication);
	applyTrait(self, traitApplication);

	[[self traitApplications] addObject: traitApplication];

	[lock unlock];
}

+ (void) applyTraitFromClass:(Class)aClass
{
	[self applyTraitFromClass: aClass 
	      excludedMethodNames: nil 
	       aliasedMethodNames: nil 
	           allowsOverride: NO];
}

+ (void) applyTraitFromClass: (Class)aClass 
         excludedMethodNames: (NSSet *)excludedNames
          aliasedMethodNames: (NSDictionary *)aliasedNames
{
	[self applyTraitFromClass: aClass 
	      excludedMethodNames: excludedNames
	       aliasedMethodNames: aliasedNames
	           allowsOverride: NO];
}

+ (void) applyTraitFromClass: (Class)aClass 
         excludedMethodNames: (NSSet *)excludedNames
          aliasedMethodNames: (NSDictionary *)aliasedNames
              allowsOverride: (BOOL)override
{
	NSSet *overridenNames = [NSSet set];

	if (override)
	{
		/* All methods in the target class can be replaced by trait methods */
		overridenNames = methodNamesForClass(aClass);
	}

	[self applyTraitFromClass: aClass 
	      excludedMethodNames: excludedNames
	       aliasedMethodNames: aliasedNames
	     overridenMethodNames: overridenNames];
}

@end
