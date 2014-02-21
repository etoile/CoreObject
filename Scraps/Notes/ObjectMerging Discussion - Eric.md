Core Object things to discuss:


*Design goals, in my opinion*

****

**Requirements:**

-   able to store projects and compound documents for Etoile, and all of
    the data types needed to represent these
-   revision control and live collaboration on generic structured data
    (nothing like this exists as far as I know)
-   data robustness, reliability (ACID)


**Nice to have:**

- portable storage format (e.g. XML)
- reducing the amount of model code - this would be nice, but even keyed
archiving isn't that bad.
-   automatic maintenance of parent/child relationships as described by
    the metamodel


**Less important:**

-   compatibility with existing model objects - we don't have a
    significant amount of legacy code



*Features to discuss:*


**Serialization, Permitted Property/Attribute Types**


 - NSDate, NSString, NSNumber, NSData permitted as primitive types
- you can use objects which support keyed archiving as property values,
and they are seamlessly convered to/from NSData


I like this because property values are either CoreObject references or
"primitive" value objects which can't contain references back to the
CoreObject graph.

We might want to extend it with support for more primitives like

-NSRange/NSRect/NSSize/NSPoint

-NSAffineTransform

-NSColor

etc., although we could just let the keyed archiving handle those



I admittedly don't have a good feel for the EtoileSerialize approach, so
we should discuss the pros/cons.



**Diff/Merge**

****

Merging difficulty scale:

easiest: editing different properties (trivial)

insert/remove elements in an ordered list (pretty simple.. diff3
algorithm) 

moving object from one container to another

hardest: splitting/recombining (e.g. divide a sentence in to two
sentences)

merging unlabeled objects: have to guess at which correspond to each
other

-   probably easy to implement naive code that works on simple cases


My code can do the first two, and I believe move detection is pretty
easy to add on top. 


Attributed strings are a real pain that I haven't fully investigated.

 - the only system I know supporting merge/diff on attributed strings is
Google Wave, and it looks very complex, and attributed string support is
hardcoded in the protocol / algorithms

- my current code won't work well with Nicolas' structured editing
concept (EtoileText). e.g. If two people make changes to the same run of
text (like underlining two different words), it will see these as
conflicting changes. 

- This shows that we will need the ability to plug in custom merge
strategies for certain types of objects.

- A custom diff / merge module for NSAtributedString objects wouldn't be
hard to write, it's just a sequence diff, but you have to update
attribute ranges when inserting/removing characters


- However, the good news is that merging doesn't need to be perfect to
be usable.

 - in collaborative editing, only the 'easy' merges need to work
perfectly (inserting elements in an ordered list), users will naturally
fix up problems themselves when they edit the same area.


**Collaboration**

recommendation: http://neil.fraser.name/writing/sync/

already 60% implemented.


**Copying Objects / Drag and Drop**

- we want the user to be able to copy/drag/pick/drop pretty much
anything (both pick/drop copy, and pick/drop reference.)


**Filesystem Layout**

For the finished Etoile environment, is storing all of the user's object
in one directory going to be a problem? Do we want to be able to have
one directory per project, or per document?


comment: that could get really complicated, and I'm not sure how useful
it would be. 


**Non-versioned content**

Versioning makes sense for anything where user input is involved, but
there are persistent things with no user input that don't really need
versioning. e.g. email? system notifications?

On the other hand, we could just version everything.


**Undo/Redo**

- multiple tracks

- selective undo


**Flexible Objects**

to what extent do we really need dictionary-like COObjects?

 i.e. are we going to need to be able to add attributes at runtime?


At runtime we can generate a custom, private COObject subclass, and
synthesize the KVC set/array accessors (e.g. the insertXYZValueAtIndex:
etc.)

Do we want to do that?



*Minor points:*


**Model description** - I'm not 100% sure that the composite/container
relationship in our metamodel is exactly the same as the "part-of"
relationship, so I wonder if we need to add another attribute to
property descriptions to describe "part-of" (also what I've called
"strong" vs " weak"). ?


**Notifying UI of changes**- can be somewhat tricky, in my experience


