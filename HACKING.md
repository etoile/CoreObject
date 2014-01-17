CoreObject HACKING
==================

For now, this is just a copy/paste of a mail exchange we had few months ago, I'll update this later and extend it...

--

The property declarations are currently using various styles and orderings for the attributes. As a starting point, I sketched some guidelines below… What do you think?

- weak attribute would only be used if it corresponds to a weak ivar
- readonly can be combined with copy or weak (see previous case)
- weak and strong would be used for object properties in place of assign and retain attributes
- assign would be used for writable primitive properties
- readwrite wouldn't be used unless a readonly property is overriden

What the position of nonatomic is the declaration? At the beginning or at the end? 

I tend to put nonatomic at the beginning, so what matters in the declaration is closer to the type. For example: 

(nonatomic, readonly, copy) NSDictionary *

I'm fine putting it elsewhere if you prefer.

