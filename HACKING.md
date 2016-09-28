CoreObject HACKING
==================

CoreObject follows the [Etoile coding style](http://etoileos.com/dev/codingstyle/) 
with some minor adjustments to cover recent Objective-C additions.


Wrapping
--------

As documented in the Etoile coding style, you should wrap text at 80 characters 
per line. For messages or functions involving long signatures or arguments, 
you can relax this limit to 120 characters per line, if it improves the code 
readibility.

To help the raw text readability, the 80 characters limit remains mandatory 
in source code documentation, comments and these three files: README, INSTALL 
and NEWS.


Code Organization
-----------------

- Use #pragma mark Accessing All Persistent Roots - in @implementation 

- Use /** @taskunit Accessing All Persistent Roots */ in @interface (put two 
blank lines before and two other ones after)

Blank Lines
-----------

- Don't use a blank line between method declarations in headers, or between
property declarations in headers.

- Add 1 blank line between properties and method declarations in headers.

- `@end`, `@interface`, `@implementation` always have one blank line before and 
after, except in the case of empty interfaces/implementations.

- Don't use blank lines between ivars.

- Use 2 blank lines between `@end` and `@implementation` when there are multiple
classes or categories in a single `.m` file.

Control Flow
------------

- Break code into small methods (don't worry about performance)

- Use guard clauses, and limit block nesting (2 levels is ok and 3 is the max 
usually)

- Assign complex complex expressions to explaining variables, or extract them 
into methods


Assertions and Exceptions
-------------------------

- Favor ETAssert() and ETAssertUnreachable() instead of more verbose ones

- Never use NSAssert() with a variable number of arguments (this is not 
supported on GNUstep), but use NSAssert1(), NSAssert2() etc.

- Add argument related exceptions to ensure all argument values are handled correctly

    - Use INVALIDARG_EXCEPTION_TEST() and NILARG_EXCEPTION_TEST() when possible
    
- Document every argument values which is not valid and related exceptions (e.g. 
For a nil name, raises a NSInvalidArgumentException.) 


State Access
------------

For init, copy, dealloc and serialization methods, you must usually access ivars 
directly (to avoid dealing with partially initialized state in accessors).

For other methods, you should use accessors, but direct ivar access is allowed 
unless:

- the class is documented as supporting subclassing

- you have benchmarked a performance issue (in this case, any subclassing 
limitation must be documented)


Initialization
--------------

- Use SUPERINIT macro (for calling the superclass -init), otherwise use this 
pattern:

        self = [super designedInitializedWithArgument: arg];
        if (self == nil)
            return nil;

- Always override -init to call the designated initializer (raising an exception 
is better than returning an invalid object if -init is unsupported)

- Keep all basic object management related methods together and close to the top 

    - this applies to methods declared in NSObject and some basic protocols such 
as NSCopying e.g. -init, -dealloc, -copyWithZone:, -description etc. 

// NOTE: We could cut the rule below, it's bit overboard probably.

- For instantiation, prefer -new to both:

    - alloc/init
    - a factory method such as +[NSArray array] that dates back from before ARC


Instance Variables
------------------

- Declare ivars in @interface (could change later)

- Prefix ivar declarations with an underscore

- Never use @protected, ivars should always be @private (unless a major 
performance issue has been shown)


Properties
----------

For classes, properties must be used when possible rather just declaring setters 
and getters. For protocols, setters and getters are preferred to properties.

- Declare all related ivars explicitly (this way, a single glance is enough to 
get an idea about the object state)

- Use explicit @synthesize (GNUstep support requires it currently)

// NOTE: For the rule just below, could be better to restrict the dot syntax to 
// properties declared with @property. 

- Use the dot syntax to read and write properties

    - this applies to implicit properties not formally declared with @property
    
    - Valid: [COObjectGraphContext new].UUID, [NSArray new].count and [NSObject new].description 

    - this doesn't apply to class methods even when they model an implicit property

    - Invalid:  NSFileManager.defaultManager and NSImage.imageTypes


Property Attributes
-------------------

- don't use atomic

- weak attribute must only be used if it corresponds to a weak ivar

- readonly can be combined with strong and weak (see the rule before too)

- weak and strong must be used for object properties in place of assign and 
retain attributes

- copy should be used instead of strong for value objects

- assign must be used for writable primitive properties

- readwrite must be used for properties not declared as readonly

- the ordering must be: atomicity, writability, memory-management, getter, setter

### Examples

    @interface COExample
    {
        @private
        id __weak _owner;
        id _owned;
        NSMutableSet *_collection;
        NSMutableSet *_container
        NSString *_name;
        NSDictionary *_elementsByName;
        id relatedObject;
    }

    @property (nonatomic, readonly, weak) id owner;
    @property (nonatomic, readonly) id derivedOwner;
    @property (nonatomic, readonly, strong) id owned;

    @property (nonatomic, readonly) NSSet *collection;
    @property (nonatomic, readonly, strong) NSMutableSet *container;

    @property (nonatomic, readwrite, copy) NSString *name;
    @property (nonatomic, readwrite, copy) NSDictionary *elementsByName;
    @property (nonatomic, readwrite, strong) id relatedObject;

    @property (nonatomic, readwrite, assign, getter=isEmpty) BOOL empty;

- Invalid: @property (nonatomic, readonly, weak) id derivedOwner

    - don't declare a weak or strong property when there is no _derivedOwner ivar

- Invalid: @property (nonatomic, readonly, strong) NSSet *collection

    - don't declare a readonly property as strong when the returned value is a defensive copy or might be (if ivar and property types are not identical, this is usually the case)

- Invalid: @property (nonatomic, readonly, copy) NSDictionary *elementsByName;

    - don't declare a readonly property as copy (copy only describes if the 
object is copied by the setter), unless you are overriding a (readwrite, copy) property

Note: for overriden properties, sometimes we have to break these rules to ensure the code compile without warnings or disable -Wproperty-attribute-mismatch with clang diagnostic pragma. For instance, NSObject.description is marked with copy, this implies COObject.description has to be marked as copy too, although copy is useless when no setter exists.


Blocks
------

- Blocks in argument should be written be split on several lines:

        return [collection filteredCollectionWithBlock: ^(id obj)
                                                        {
                                                            return (BOOL)![obj isDeleted];
                                                        }
                                                sorted: YES];

Take note that the opening brace must be on a newline.
If a block is the last argument, it can either be indented to line up with the colon:

        return [collection filteredCollectionWithBlock: ^(id obj)
                                                        {
                                                            return (BOOL)![obj isDeleted];
                                                        }];

Or, to make the lines shorter, it can be moved down to the next line:

        return [collection filteredCollectionWithBlock: 
                    ^(id obj)
                    {
                        return (BOOL)![obj isDeleted];
                    }];

- For the block signature, there is a space just after the return type:

    - Return Type + space + caret + Argument List
    
- Blocks with no arguments should still get empty parens: `^()`

### Formatting Examples

- Block variable

        NSObject * (^blockVar)(id, NSDictionary *) = ^(id object, NSDictionary *bindings) 
        {
            // whatever
        };

- Block typedef

        typedef NSArray * (^COContentBlock)(void);

- Block type used as argument type (but it's better to use a block typedef usually)

        + (id)actionWithBlock: (NSObject * (^)(id object, NSDictionary *bindings))aBlock;
