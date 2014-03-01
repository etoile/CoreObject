Etoile Developer Guide
======================

Copyright Christopher Armstrong 2011.

Licensed under the MIT License.

Introduction
------------

This document is a reference for developers who want to develop
applications and libraries using Etoile.

EtoileFoundation
================

EtoileFoundation is a set of extensions to Objective-C and the
gnustep-base (Foundation) library that enhance its functionality. It is
used to support many features in other Etoile libraries, such as
ObjectMerging and EtoileUI. It extends the functionality that is
available in gnustep-base or Foundation (as its known in Cocoa). We
assume that in the following you are familiar with the concepts in
Foundation, especially Key Value Coding and Key Value Observing.

Overview
--------

One of the first new concepts that EtoileFoundation introduces is
Property Value Coding (PVC). A property is similar to a key-path in KVC,
that is, it is a similar extension to the framework that supports
calling setter and getter methods indirectly by specifying strings.
EtoileFoundation adds the ability to specify methods which are not
normally KVC-compliant (but are PVC compliant), and it supports better
metadata than KVC in determining which properties are available to be
changed or observed.

EtoileFoundation also introduces a model description repository, which
is a runtime metadata system for describing entities that are available
to be instantiated and used in a programme. An entity is like a class,
and closely corresponds to a class in Objective-C. It has properties
which can be described by their name and type and relationship to other
entities. It is used to support frameworks like ObjectMerging to more
easily persist a class without custom serialisation code. EtoileUI uses
it to quickly build a GUI based around the model of an object. It will
eventually be integrated with PVC so that the model of an entity is
available through PVC to determine the available property names.

Higher Order Messaging (or HOM) adds an API for manipulating objects by
introducing methods that take a message send as its parameter, but
without the special syntax or paridigms of a functional language. It
makes it simple to do things like send the same message to all the
objects in a collection or call a method in the run loop of a new
thread. This is all done by sending objects a special prefix message, to
which in turn you send the message you want to be treated in a special
way.

The collection API extensions (known collectively by the ETCollection
protocol) makes it easier to treat disparate collections in the same way
in terms of access and observing changes (through KVO). This is used by
EtoileUI to streamline the display of collections through
`ETLayoutItemGroup`s and in ObjectMerging to simplify the persistence of
collection properties and relationships to other objects. It also makes
it possible to use HOM to quickly manipulate collections of objects.

Property Value Coding
---------------------

Property Value Coding is a simple extension to Key Value Coding (KVC)
that supports reading and writing properties in a slightly different and
more extensible way. It extends the behaviour of KVC to make more
methods compatible and also adds functionality to KVO to automatically
observe an object’s properties.

### What is a property?

Every object has methods that are used to retrieve attributes of the
object ("getter" methods) and to change the attribute of an object
(`"setter"` methods). Typically these accessor methods follow the same
naming convention between classes, where getter methods begin with a
lower case letter and use camel case to retrieve a value, and the
corresponding setter method begins with `set` and then the
uppercase-case led camel case name used in the getter.

This naming convention, along with the ability to introspect objects to
call their methods by name (and not just with a selector), is combined
to allow accessor methods to accessed as properties. A property is
described by just a string that contains the name of the getter method,
and this method of accessing properties is called Property Value Coding
in EtoileFoundation. Combined with the Property Value Coding methods
that are added as a category to each class, it becomes possible to
retrieve property values and observe changes in properties by specifying
strings for the property and calling a consistent API.

On its own, the PVC APIs don’t appear to provide much usefulness.
Compared to Cocoa, a property is the same as a key-path in Key-Value
Coding and Key-Value Observing. It is used extensively in Cocoa’s APIs
and EtoileFoundation to rationalise access to model object properties
from the user-interface definition so that you do not have to write
extensive amounts of "glue" code that moves values between the
user-interface and a model object. We also use it in ObjectMerging so
that we can determine what properties are persistable.

In EtoileFoundation, more than the normal accessor methods are available
as properties. Additionally, it becomes possible to define which methods
are available as properties for accessing and observing.

### Accessing properties

You retrieve the value of a property through the `-valueForProperty:`
method by specifying the property name in the same way as KVC.
Similarly, you can change the value of a property through the
`-setValue:forProperty:` method. In most cases, you will not use these;
they exist to support other frameworks, and to be overriden in your own
classes to improve their flexibility.

You retrieve the value of a property using the name of the property in
the same manner that you specify a key for KVC. For example, with a
class that has a `-setAddress:` method and a `-address` method, you
would retrieve and set the property `address` using the following type
of code:

    Address *homeAddress;
    Contact * myContact;
    ...
    homeAddress = [myContact valueForProperty: @"address"];
    businessAddress = [Address addressWithString: [@"89 Broadway, Manchester Hill 28372"];
    [myContact setValue: businessAddress forProperty: @"address"];

### Determining available properties

The properties that are available on an object are returned by the
`-propertyNames` method. It is not usually necessary to call this method
directly. Rather, it is used primarily by the PVC methods
`-valueForProperty:` and `-setValue:forProperty:` to determine which
properties are available . If a property name that is passed to the
latter of these methods is not in the list, the value `NO` is returned.

The method `-observableKeyPaths` is similar to `-propertyNames`, but it
is the list of KVC-compliant properties that can be observed. [Observing
property changes](#Observing-property-changes) for more details.

It is therefore more important to make sure that your implementations of
these methods is correct so that consumers of your class can use PVC
with it. This process is discussed in See [Making a class
compliant](#Making-a-class-compliant)

### Making a class compliant

Property Value Coding expects the properties that are available on an
object to be declared by overriding the `-propertyNames` method. Your
implementation should extend the array returned from the result of the
superclass operation to include the properties that are added by the
subclass. Conversely, you can determine the properties that are
accessible on an object by calling its `-propertyNames` method. It
always returns an array of the available properties for that object. It
is important that any implementation of this method is stable for the
same object, otherwise exceptions will be generated when observing
changes in an object’s properties ([Observing
Properties](#Observing-Properties)).

For example, the following class has the properties `address`,
`phoneNumber` and `name`. We show a class declaration and an example of
implementing the `-propertyNames` method.

     Contact : Person
    ...
    - (NSString*)name;
    - (NS

### Extending KVC

The main PVC methods, `-valueForProperty:` and `-setValue:forProperty:`
are able to be overridden to extend the functionality of an object. For
example, ObjectMerging uses them to control changes in a COObject
instance for persisting object changes. EtoileUI’s ETLayoutItem uses
them to first check a represented object contains the specified
property, and if the represented object doesn’t support it, it will
store or retrieve the property value from itself.

In addition, PVC lets us access properties that are not usually
accessible to Key Value Coding. For example, the `-count` method of
NSArray and NSDictionary are both not typically accessible to KVC, but
they are accessible to PVC. It also does not throw an exception when
when a property value is not found on a `-setValue:forProperty:` call.
As mentioned in the previous section, it instead just returns a `BOOL`
value indicating whether or not the property was successfully set.

### Observing property changes

It is possible to register yourself as an observer of property changes
in an object by calling the `-addObserver:` method with a reference to
the object that should receive the notifications. The set of properties
that is observed is determined by the set returned from the
`-observableKeyPaths` method.

This feature is just an extension to Key Value Observing (KVO) and uses
the same mechanisms to register and unregister and notify your observer
object. Your observer will receive notifications through the normal
`-observeValue:forKeyPath:change:context:` callback.

Similarly, an object can un-register from change notifications with the
`-removeObserver:` method.

Model Description Repository
----------------------------

The Model Description Repository is a runtime metadata repository of
entities available in an application or tool. It is used to discover the
entities that can be instantiated, and the properties (through Property
Value Coding) on objects of those entities that are available for
accessing and changing.

Each application has a main repository, that is accessed through the
`+[ETModelDescriptionRepository mainRepository]` method. In a
repository, you can find descriptions of:

-   entities, which are types that can be instantiated

-   packages, which are groups of related entities

-   properties, which are attributes of a entity that can be accessed

### Defining new Entity Descriptions

Entity descriptions for classes that you define are best declared by
overriding the `+newEntityDescription` method for your class. You can
obtain a new entity description instantiated for your class by calling
`+newBasicEntityDescription` and then by filling it out with details of
your entity’s properties. Both these methods return an instance of
`ETEntityDescription`.

However, you should only fill it out if the returned entity
description’s class is equal to your class name. You need this check to
prevent accidentally extending the entity description for a subclass
where the subclass has not overridden `+newEntityDescription`. If the
returned entity description does not match your class, you should return
the entity description that you received so that the subclass has its
own entity description.

#### Parent

In your implementation, you need to set the parent entity and set the
properties that your subclass exposes (not those inherited from a parent
class). The parent entity is set through the `-setParent:` method,
specifying the entity description of your parent retrieved from the
entity description repository, or its name as a string (see the
following section for more details on referring to entities by name).

#### Properties

You can define properties by creating new instances of
`ETPropertyDescription`. At a minimum, you need to set its name and its
type (another entity description. You always need to specify the type
for even simple properties like strings (`@"Anonymous.NSString"`) and
dates (`@"Anonymous.NSDate"`). However, for multi-valued properties, you
should specify the type stored in the collection, not the type of
collection itself (like `NSArray` or `NSSet`).

Instead, multivalued properties have some extra fields which are used to
deduce:

-   the type of the collection

-   the way it is stored

-   how the stored objects refer back to their owner.

The first part of specifying a collection property is to set
`-isMultivalued` to `YES`.

### Referring to existing entity descriptions

Entity descriptions are usually placed in packages. The package is
specified as part of the entity name when looking it up in the model
description repository using a dot (`.`) notation in the form of
`Package.EntityName`. If an entity description is defined without
specifying a package, it goes into a special package called `Anonymous`.
You still need to specify this Anonymous package when referring to
existing entities that are placed here.

When you define your entity description, you have the option of
specifying either the corresponding entity description object, or a
string containing the name of the entity. Although the API is usually
typed to specify an instance of `ETEntityDescription`, you can use the
latter option by typecasting a string containing the entity name. This
option is only available when specifying property types and parent
types, and only when defining new entity descriptions. The name is
resolved to the real entity description at a later time on a call to the
`-[ETModelDescriptionRepository resolveNamedObjectReferences]` method.

EtoileFoundation creates entity descriptions for common scalar
Foundation classes like `NSString` and `NSNumber` in the Anonymous
package. You can refer to these in property descriptions by specifying
their full package and entity name e.g. `@"Anonymous.NSString"`.

Higher Order Messaging
----------------------

### Introduction

Higher Order Messaging (HOM) is a utility that relies on second-chance
messaging to abstract away the details of iteration, callbacks,
delegation and other common tasks that require very similar code to
work. A Higher Order Message is a message (in the object-oriented sense
of *sending a message*) that takes another message as its argument.
Because Objective-C and Smalltalk don’t exactly support taking a message
send as an argument, it has to be implemented in slightly more
round-about way, but that is still intuitive and concise.

The key concept behind HOM is the idea of sending a prefix message to an
object, before sending the specific message to the proxy object returned
by that prefix message. The prefix message specifies what sort of
general operation you want to perform, while the followup message
specifies the operation to be repeated or performed in some other
context (e.g. inside an exception handler or on another thread). For
example, if you want to send a message to each object in a collection,
and put the results into another collection, you would need to do
something like:

    NSArray *originalCollection;
    NSArray *collectedResults = [NSMutableArray array];

    for (int i = 0; i < [originalCollection count]; i++)
    {
        id myObj = [originalCollection objectAtIndex: i];
        [collectedResults addObject: [myObj retrieveSomeProperty]];
    }

Most of what occurs above is boilerplate, but without extra language
constructs (such as those found in functional programming), its
difficult to abstract the iteration details and make it easier to read.
With HOM, the same result is achieved through the following code:

    NSArray *originalCollection;
    NSArray *collectedResults;

    collectedResults = [[originalCollection mappedCollection] retrieveSomeProperty];

In this case, the `-mappedCollection` method will return a sort of proxy
object. When it receives its next message, it will catch it through the
second-chance Objective-C mechanism via the `-forwardInvocation:`
method, and then relay the followup message to each object in the
collection. It effectively implements the for loop for you. On each
iteration, it takes the result of the `-retreiveSomeProperty` operation
and adds it to a new collection. At the end of the method, it will
return the new collection.

### Manipulating collections

### Sending a message only if the target responds to it

Typically when implementing delegates that have informal protocols, you
want to make sure that if you send it a message, that the delegate
responds to that message. This is typically implemented by code such as
the following:

    if ([delegate respondsToSelector: @selector(object:didReceiveNotification:)])
        [delegate object: self didReceiveNotification: YES];

The `-ifResponds` higher order method will only send the subsequent
message if the target of the method responds to it. It lets you simplify
the above code to the following:

    [[delegate ifResponds] object: self didReceiveNotification: YES];

ETCollection Protocol and Implementation
----------------------------------------

ObjectMerging Framework
=======================

ObjectMerging is Etoile’s persistence framework. It provides
object-level persistence that stores the entire history of changes made
to an object graph. It is designed to be used in user applications to
provide an easy-to-use layer for persisting documents with full
undo/redo support across the document’s lifetime. Importantly, it also
provides full-text indexing of objects so that documents can be searched
for quickly by a user.

This framework supercedes CoreObject, which was an earlier attempt to
provide a similar level of functionality.

Background
----------

ObjectMerging provides object-level persistence. A persistent object in
ObjectMerging has COObject as its base class. Every persistent object
also has a unique identifier, which is represented as a UUID.[^1] These
are objects in the traditional OOP sense, so they have properties and
inter-object relationships.

The framework stores the history of each object. Each set of changes
made across a group of objects is broken down into a revision. A
revision is much the same as a commit in source code control systems,
where a commit is a set of changes made against a group of files; we use
the same terminology in ObjectMerging.

Each object is persisted to an on-disk store. Etoile typically creates
one object store per user, but custom applications can create their own
object stores. The intention is that a user stores all their documents
and settings in the same persistent store on disk.

Because every object is saved in the same store, so it is necessary to
provide some sort of separation between groups of related objects. Each
object has a root object, which acts as a sort of container for a set of
objects. Each revision applies only to one root object; changes to
objects that have a different *root* will have multiple revisions, one
per root object. In this way, a root object acts like the base object of
a document and provides clear separation between unrelated documents.
This separation makes the behaviour of undo/redo more predictable and
easier to understand.

Getting Started
---------------

### Dependencies

ObjectMerging depends upon the gnustep-base library and
EtoileFoundation. Information on how to set these up is given earlier in
this document. Additionally, you will need the UnitKit framework if you
wish to run the test cases.

### Project GNUmakefile

After installing ObjectMerging into your GNUstep environment, you will
just need to include the ObjectMerging framework as a library
dependency. For the following example project called `CalendarApp`, we
define the GNUmakefile as such:

    include $(GNUSTEP_MAKEFILES)/common.make

    APPLICATION_NAME = CalendarApp

    $(APPLICATION_NAME)_OBJC_FILES = ...
    $(APPLICATION_NAME)_OBJC_LIBS = -lObjectMerging

    ...

    include $(GNUSTEP_MAKEFILES)/application.make

Creating new core object class
------------------------------

An object that can be persisted with ObjectMerging is one that inherits
from the `COObject` class. Additionally, it has a model defined for it
in the default model repository. For example, imagine we have a new type
called `Calendar` which stores a set of `Appointment` instances. We need
to first define the interface for such a class:

    @interface Calendar : COObject
    {
            NSMutableArray *appointments;
            NSDate *today;
    }

    - (NSArray*)appointments;
    - (NSDate*)today;
    @end

### Defining the Model

ObjectMerging needs a model for this new class in order to know how to
persist it and retrieve it again. The model is stored in default model
description repository, which is retrieved by calling
`+[ETModelDescriptionRepository mainRepository]`.

We define the model by overriding the
`+(ETEntityDescription*)newEntityDescription` method to create our own
model. This method must call `+newBasicEntityDescription` to retrieve a
new entity description for this class. It must also set the model
properties if our `[self class]` value is equal to the current class
(like what is done in an `+initialize` method), otherwise, we could
accidentally augment the model for classes further down the model tree.

In the following example, we define the model for the `Calendar` class
above, which has two properties: `-today` and `-appointments`. The first
property is just a simple scalar value storing today’s date as an
`NSDate` instance, while `-appointments` stores a list of `Appointment`
instances in an array.

    @implementation Calendar
    + (ETEntityDescription*)newEntityDescription
    {
      ETEntityDescription *desc = [self newBasicEntityDescription];
      if ([[desc name] isEqual: [Calendar className]])
      {
        ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
        [desc setParent: (id)@"Anonymous.COObject"];

        ETPropertyDescription *today = [ETPropertyDescription
          descriptionWithName: @"today"
                         type: [repo descriptionForName: @"Anonymous.NSDate"]];
        
        ETPropertyDescription *appointments = [ETPropertyDescription
          descriptionWithName: @"appointments"
                         type: (id)@"Anonymous.Appointment"];
        [appointments setMultivalued: YES];
        [appointments setOrdered: YES];
        
        [desc setPropertyDescriptions: A(appointments, today)];
        [[[desc propertyDescriptions] mappedCollection] setPersistent: YES];
      }
      return desc;
    }

    ...
    @end

There are two things to notice about the `-appointments` property when
we set its type by typecasting the string `@"Anonymous.Appointment"` as
an `id`. The first is the `Anonymous` part of the name string: it refers
to the `Appointment` entity in the default package. This prefix is
needed for a class’s generic entity description in the model repository.
You can retrieve the entity description for any class with this
prefix.[^2]

The second part to notice is the typecast. Typically you provide an
instance of `ETEntityDescription` loaded from the repository. In this
case, we have used a mechanism in EtoileFoundation that resolves an
entity by name if we specify a string instead of a
`ETEntityDescription`. It’s a useful shortcut, but more importantly, it
means we don’t need to try and load the entity description for another
class that we need. The model description repository will try and
resolve the entity description for the `Appointment` class at some later
stage.

Also notice that we called `-setMultivalued:` and `-setOrdered:`. This
indicates that `-appointments` is a collection property that is ordered
(i.e. an array) as opposed to unordered (i.e. a set).

The `A()` macro used in the `-setPropertyDescriptions:` call is a
shortcut for `-[NSArray arrayWithObjects: , ...]` provided by
EtoileFoundation.

The last line uses EtoileFoundation’s Higher Order Messaging (HOM)
feature to retrieve the list of properties we just defined and call
`-setPersistent` against each one so that ObjectMerging will recognise
it as a property it needs to persist.

For more information about defining models or anything about
EtoileFoundation, see the chapter on EtoileFoundation or consult the API
documentation for `ETModelDescriptionRepository`.

### Designing and implementing the core object

Your persistent object does not need to have a particularly different
design in order to use ObjectMerging. The main issues to check for are
property implementation and object initialisation.

#### Property implementation

The properties you define need to be reflected in the API of your class
as setter and getter methods that are compatible with Property Value
Coding (PVC). For all intents and purposes, PVC is the same as Key Value
Coding (KVC), except that it allows things not typically considered
attributes of a class to be retrieved.

PVC is used to both save and restore the values of your class; you don’t
need to write any special persistence code. You need to make sure that
any persistent properties you defined in your model have both setter and
getter methods. If you don’t provide setter methods, the underlying KVC
implementation will attempt to retrieve the values of instance variables
with the same name (unless you overrode
`+accessInstanceVariablesDirectly` to return `NO`).

Nor is there is no need to add special code to your getters or setters
to inform the editing context that your object has changed:
ObjectMerging uses Key Value Observing to monitor changes made to your
object when it is inserted into an editing context. You just need to
ensure you play by the normal KVO rules when accessing instance
variables *directly*, ensuring that you call `-willChangeValueForKey:`
and `-didChangeValueForKey:` appropriately.

#### Initialisation

You should also take care as to how your default `-init` method is used
to initialise your class. You can have consumers of your class call a
custom init method, in which case you can initialise the default values
of your class according to their input, but they must call
`-becomePersistentInContext: rootObject` afterwards. On the other hand,
if your class is instantiated through the
`-[COEditingContext insertObjectWithEntityName:` method, your `-init`
method will not be called.

If you still want to perform some initialisation every time your class
is instantiated (regardless of whether they use a custom initialiser or
the COEditingContext), you should override the `-didCreate` notifier,
which is called the very first time an object is created. It isn’t
called when an object is retrieved againt from the persistent store.

Instantiating a new object
--------------------------

As described earlier, each object is stored in a persistent store. You
don’t access the store directly, but through an editing context. The
editing context tracks the set of changes made to each object and
persists them when the `-commit` method is called.

In ObjectMerging, the store is represented by a `COStore` object. Unless
your application has its own store, you will rarely need to interact
with it. The editing context is accessed through a `COEditingContext`
object, which you instantiate yourself or through
`-[COObject editingContext]` from an already loaded object.

An new root object is created for the first time by calling
`-[COEditingContext insertObjectWithEntityName:]`. This creates the
object with a default initialiser and registers it for persistence in
the context. Alternatively, you can instantiate the object through a
normal `-alloc` and `-init` sequence and then call
`-becomePersistentInContext:rootObject:` to make it available for
persistence.

In the following example, we show the instantiation through both means.

     COStore *store = [[COStore alloc]
                    initWithURL: [NSURL fileURLWithPath: @"TestStore.db"]];

            // Create the editing context
            COEditingContext *ctx = [[COEditingContext alloc]
                    initWithStore: store];

        // Create a new root object of type Calendar
            Calendar *calendar = [ctx insertObjectWithEntityName: @"Anonymous.Calendar"];

        // Create a new Appointment object and attach it to the context
            Appointment *firstAppt = [[Appointment alloc]
                    initWithStartDate: [NSDate date]
                              endDate: [NSDate dateWithTimeIntervalSinceNow: 3600]];
            [firstAppt becomePersistentInContext: ctx
                                      rootObject: calendar];
            [calendar addObject: firstAppt forProperty: @"appointments"];
     
        // Commit the changes
        [ctx commit];

The first object (of type `Calendar`) doesn’t specify a root object, so
it becomes a root object in the store. The second object is instantiated
with `calendar` as its root object. We then use the PVC method
`-addObject:forProperty:` to add the new appointment to the calendar’s
`-appointments` property.

The last part is to commit the changes to the editing context, which
saves them to the store as part of a revision. This revision can be
accessed through the `-[COObject revision]` object on the object. At
this point, the objects are still usable and can be modified and
committed again as part of a new revision through the same means.

Undo and Redo
-------------

ObjectMerging supports undo and redo at the persistence framework level.
It is implemented by means of a commit track, which is persistent
metadata that supports a undo redo stack. The mechanics of revisions and
commit tracks is discussed in See [Understanding the revision
model](#Understanding-the-revision-model).

An undo in ObjectMerging reverts the object to the revision that was in
place before this one. Performing undo again will revert to the revision
that was in place before that. By that definition, redo will revert the
undo i.e. the later revision will be restored.

Undo and Redo only applies to one root object. All the objects that
reference the root object as their root will participate in the
undo/redo.

The model of undo in ObjectMerging is designed to be reasonably
consistent with that in advanced user interfaces, which have full
undo/redo stacks. Multiple undos will step back through the history of
changes until they reach the beginning again, while multiple redos will
follow the changes up until the latest point. This is where the word
*track* comes in, in that undo and redo follow the commit track,
restoring one consecutive commit at a time.

Also like in a GUI, making a new commit after performing one or more
undos will make those revisions inaccessible to a redo. However, the
revisions are not lost, and can be switched to manually if they are
known. The `COCommitTrack` does not support this explicitly yet, but
enough metadata is stored that such an implementation is virutally
trivial.

In order to perform an undo, it is just a matter of accessing an
object’s commit track and calling `-undo` against it. The following
example shows performing undo against the `calendar` object defined in
the previous example:

     [[calendar commitTrack] undo];

Similarly, a redo is performed by switching to the revision of a root
object that was in store before the undo. It is perfomed by calling
`-redo` against the commit track.

        [[calendar commitTrack] redo];

Understanding the revision model
--------------------------------

In the [Background](#Background), we discussed the idea of root objects
and revisions. Just to recap, each root object represents a group of
related objects. Each change to those group of objects (including the
original state of the object when it was created) are stored in one or
more commits or revisions. Those revisions are exclusive to that root
object; root objects cannot share revisions, even if they reference each
other.

This separation is important. Without it, unrelated objects that were
changed at the same time could participate in the same revision. This
would make it difficult to undo the changes on a particular document
without involving objects from unrelated documents.

This means that revisions are related to each other in the way that they
*build* upon each other to form the history of the object. The base
revision is the revision that comes before another revision. If you were
to follow the base revision back recursively, you would arrive at the
first revision for an object. You could imagine graphing this revision
track with circles representing each revision, and an arrow from one
revision to another representing the link between a revision and its
base revision.

In normal usage scenarios, this revision track just looks like a
straight line of circles pointing to one other circle, forming a linear
revision history for a root object. However, this model is too
simplistic to support undo and redo in a simple way. It is simple enough
to support undo by moving back to a previous revision. In this way, you
would store a simple pointer to the current revision. Supporting redo
would just increment that pointer. In this model, an undo simply
switches the revision of a root object to a previous object. All the
objects under the root object will be reloaded so that they reflect
their state under the previous revision.

However, this model suffers from the not-so-obvious (and quite limiting)
flaw that means that you cannot create a new revision, except at the
very top of the revision track. This useless from a user point of view,
as it means the user cannot undo some of their changes and then continue
editing from that point onwards.

Another model, which is expressed as history tracks, is to implement
undo by creating a difference between two revisions, and applying this
difference as a *new revision* on top of the revision track. Redo is
implemented in the same way. However, repeatedly undoing becomes more
and more complex, as you suddenly have to track the point in the
revision track from which you began undoing and point at which the next
undo (if it should occur) would commence. Multiple sets of undo, new
commits and redo have to track parts of the line on which they can undo
and which parts they cannot. This seems to become unwieldly very
quickly.

ObjectMerging uses a conceptually simpler model to implement commit
tracks. As we mentioned before, each revision has a base revision.
However, there is no need for a revision track to be a straight line. A
particular revision might be, in fact, a base revision for more than one
other revision. In this model, the history of revisions is less of a
track, and more of a tree.

That is still not sufficient to support an undo stack. We still need to
know what revision we are at. We also need to know what revisions we can
move forward and backward along. Just storing the base revision is not
enough, as it prevents a redo from just moving forward.

What happens internally is that we create a commit track node, which is
a node with a pointer to another revision. It also has a backwards and
forwards pointer to other commit track nodes. We then store a pointer to
the current commit track node in the commit track. A new revision also
creates a new commit track node, pointing to the previous one. Undo will
move the commit track pointer to the previous node, restoring an older
revision. Redo works in reverse, by moving the pointer forward. In
addition, we rewrite the forward pointers of the current commit track
node before we make a new commit, so that the commit track reflects the
new path that is created when a user undoes a revision and then makes a
new change.

This means that the user can undo all the way back to the beginning of
their document, or redo all the way back along the current commit track.
It also means that there is orphan commit track nodes that point to
revisions which are no longer accessible along the main line of the
commit track.

License
=======

The MIT License (MIT)

Copyright (c) 2011 Christopher Armstrong

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[^1]: UUID stands for Universally Unique Identifer. It is a method for generating identifiers that are guaranteed to be unique in a distributed computing setting. See ITU-T Rec. X.667, ISO/IEC 9834-8:2005 or RFC 4122 for more details

[^2]: EtoileFoundation permits the creation of new "entity" descriptions that are derived from existing entity descriptions for classes, and allows you to put them into different packages. The Anonymous package is the default.
