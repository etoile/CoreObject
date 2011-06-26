#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/EtoileFoundation.h>

#define SA(x) [NSSet setWithArray: x]

@interface TestModelElementDescription : NSObject <UKTest>
@end

@interface TestPropertyDescription : NSObject <UKTest>
{
	ETPropertyDescription *bookAuthor;
	ETPropertyDescription *authorBooks;
	ETEntityDescription *book;
	ETEntityDescription *author;
}

@end

@interface TestPackageDescription : NSObject <UKTest>
{
	ETPackageDescription *package;
	ETPackageDescription *otherPackage;
	ETEntityDescription *book;
}
@end

@interface TestEntityDescription : NSObject <UKTest>
{
	ETEntityDescription *book;
	ETPropertyDescription *title;
	ETPropertyDescription *authors;
}

@end


@implementation TestModelElementDescription

- (void) testFullName
{
	id litterature = [ETPackageDescription descriptionWithName: @"litterature"];
	id book = [ETEntityDescription descriptionWithName: @"book"];
	id title = [ETPropertyDescription descriptionWithName: @"title"];
	id authors = [ETPropertyDescription descriptionWithName: @"authors"];
	id isbn = [ETPropertyDescription descriptionWithName: @"isbn"];

	UKStringsEqual(@"litterature", [litterature fullName]);
	UKStringsEqual(@"book", [book fullName]);
	UKStringsEqual(@"title", [title fullName]);

	[book setPropertyDescriptions: A(title, authors)];

	UKStringsEqual(@"book.title", [title fullName]);

	[litterature addEntityDescription: book];
	[litterature addPropertyDescription: isbn];

	UKStringsEqual(@"litterature.book.title", [title fullName]);
	UKStringsEqual(@"litterature.book.authors", [authors fullName]);
	UKStringsEqual(@"litterature.isbn", [isbn fullName]);

	[book removePropertyDescription: title];
	[litterature removeEntityDescription: book];
	[litterature removePropertyDescription: isbn];

	UKStringsEqual(@"title", [title fullName]);
	UKStringsEqual(@"book.authors", [authors fullName]);
	UKStringsEqual(@"isbn", [isbn fullName]);

}

@end

@implementation TestPropertyDescription

- (id) init
{
	SUPERINIT;
	bookAuthor = [[ETPropertyDescription alloc] initWithName: @"author"];
	authorBooks = [[ETPropertyDescription alloc] initWithName: @"books"];
	book = [[ETEntityDescription alloc] initWithName: @"book"];
	author = [[ETEntityDescription alloc] initWithName: @"author"];
	return self;
}

- (void) dealloc
{
	DESTROY(bookAuthor);
	DESTROY(authorBooks);
	DESTROY(book);
	DESTROY(author);
	[super dealloc];
}

- (void) testBasicOpposite
{
	ETPropertyDescription *other = [ETPropertyDescription descriptionWithName: @"other"];

	[book addPropertyDescription: bookAuthor];
	[author addPropertyDescription: authorBooks];

	UKNil([bookAuthor opposite]);
	UKNil([authorBooks opposite]);

	[bookAuthor setType: book];
	[bookAuthor setOpposite: authorBooks];

	UKObjectsEqual(bookAuthor, [authorBooks opposite]);
	UKObjectsEqual(book, [authorBooks type]);
	UKObjectsEqual(author, [bookAuthor type]);

	[other setOpposite: authorBooks];

	UKObjectsEqual(other, [authorBooks opposite]);	
	UKNil([authorBooks type]);
	UKNil([bookAuthor opposite]);
	UKNil([bookAuthor type]);
}

- (void) testTypeUpdateForOpposite
{
	ETEntityDescription *publisher = [ETEntityDescription descriptionWithName: @"publisher"];
	ETPropertyDescription *publisherBook = [ETPropertyDescription descriptionWithName: @"book"];

	[publisher addPropertyDescription: publisherBook]; 
	[book addPropertyDescription: bookAuthor];
	[author addPropertyDescription: authorBooks];
	[bookAuthor setOpposite: authorBooks];

	UKObjectsEqual(book, [authorBooks type]);
	UKObjectsEqual(author, [bookAuthor type]);

	[publisherBook setOpposite: bookAuthor];

	UKObjectsEqual(book, [publisherBook type]);	
	UKObjectsEqual(publisher, [bookAuthor type]);

	[publisher removePropertyDescription: publisherBook];

	UKObjectsEqual(book, [publisherBook type]);
	UKNil([bookAuthor type]);
}

@end

@implementation TestPackageDescription

- (id) init
{
	SUPERINIT;
	package = [[ETPackageDescription alloc] initWithName: @"test"];
	otherPackage = [[ETPackageDescription alloc] initWithName: @"other"];
	book = [[ETEntityDescription alloc] initWithName: @"book"];
	return self;
}

- (void) dealloc
{
	DESTROY(package);
	DESTROY(otherPackage);
	DESTROY(book);
	[super dealloc];
}

- (void) testEntityDescriptions
{
	ETEntityDescription	*authors = [ETEntityDescription descriptionWithName: @"author"];

	UKNotNil([package entityDescriptions]);
	UKTrue([[package entityDescriptions] isEmpty]);

	[package setEntityDescriptions: S(book, authors)];

	UKObjectsEqual(S(book, authors), [package entityDescriptions]);
}

- (void) testAddPropertyDescription
{
	ETPropertyDescription *title = [ETPropertyDescription descriptionWithName: @"title"];
	ETPropertyDescription *isbn = [ETPropertyDescription descriptionWithName: @"isbn"];

	[book addPropertyDescription: title];
	[otherPackage addPropertyDescription: isbn];

	UKObjectsEqual(S(isbn), [otherPackage propertyDescriptions]);
	UKObjectsNotEqual(otherPackage, [isbn owner]);
	UKObjectsEqual(otherPackage, [isbn package]);

	[package addPropertyDescription: title];
	[package addPropertyDescription: isbn];

	UKObjectsEqual(S(title, isbn), [package propertyDescriptions]);
	UKObjectsEqual(book, [title owner]);
	UKObjectsEqual(package, [title package]);	
	UKObjectsNotEqual(package, [isbn owner]);
	UKObjectsEqual(package, [isbn package]);	
}

- (void) testBasicAddEntityDescription
{
	ETEntityDescription	*authors = [ETEntityDescription descriptionWithName: @"author"];

	[otherPackage addEntityDescription: authors];

	UKObjectsEqual(S(authors), [otherPackage entityDescriptions]);
	UKObjectsEqual(otherPackage, [authors owner]);

	[package addEntityDescription: book];
	[package addEntityDescription: authors];

	UKObjectsEqual(S(book, authors), [package entityDescriptions]);
	UKObjectsEqual(package, [book owner]);
	UKObjectsEqual(package, [authors owner]);
	UKTrue([[otherPackage entityDescriptions] isEmpty]);
}

- (void) testExtensionConflictForAddEntityDescription
{
	ETPropertyDescription *title = [ETPropertyDescription descriptionWithName: @"title"];
	[book addPropertyDescription: title];

	[package addPropertyDescription: title];

	UKObjectsEqual(S(title), [package propertyDescriptions]);

	[package addEntityDescription: book];

	UKObjectsEqual(S(book), [package entityDescriptions]);
	UKObjectsEqual(package, [book owner]);
	UKObjectsEqual(book, [title owner]);
	UKObjectsEqual(package, [title package]);
	UKTrue([[package propertyDescriptions] isEmpty]);
}

@end

@implementation TestEntityDescription

- (id) init
{
	SUPERINIT;
	book = [[ETEntityDescription alloc] initWithName: @"book"];
	title = [[ETPropertyDescription alloc] initWithName: @"title"];
	authors = [[ETPropertyDescription alloc] initWithName: @"authors"];
	return self;
}

- (void) dealloc
{
	DESTROY(book);
	DESTROY(title);
	DESTROY(authors);
	[super dealloc];
}

- (void) testSetPropertyDescriptions
{
	UKNotNil([book propertyDescriptions]);
	UKTrue([[book propertyDescriptions] isEmpty]);

	[book setPropertyDescriptions: A(title, authors)];

	UKObjectsEqual(S(title, authors), SA([book propertyDescriptions]));
	UKObjectsEqual(S(title, authors), SA([book allPropertyDescriptions]));
}

- (void) testAddPropertyDescription
{
	ETEntityDescription *other = [ETEntityDescription descriptionWithName: @"other"];
	[other addPropertyDescription: title];

	UKObjectsEqual(A(title), [other propertyDescriptions]);
	UKObjectsEqual(other, [title owner]);

	[book addPropertyDescription: title];
	[book addPropertyDescription: authors];

	UKObjectsEqual(S(title, authors), SA([book propertyDescriptions]));
	UKObjectsEqual(S(title, authors), SA([book allPropertyDescriptions]));
	UKObjectsEqual(S(@"title", @"authors"), SA([book propertyDescriptionNames]));
	UKObjectsEqual(title, [book propertyDescriptionForName: @"title"]);
	UKObjectsEqual(book, [title owner]);
	UKObjectsEqual(book, [authors owner]);
	UKTrue([[other propertyDescriptions] isEmpty]);
}

- (void) testAllPropertyDescriptions
{
	ETEntityDescription *other = [ETEntityDescription descriptionWithName: @"other"];
	[other addPropertyDescription: title];

	[book setParent: other];

	UKObjectsEqual(A(title), [book allPropertyDescriptions]);
	UKObjectsEqual(A(title), [other allPropertyDescriptions]);

	[book addPropertyDescription: authors];

	UKObjectsEqual(S(title, authors), SA([book allPropertyDescriptions]));

	ETEntityDescription *root = [ETEntityDescription descriptionWithName: @"root"];
	ETPropertyDescription *identity = [ETPropertyDescription descriptionWithName: @"identity"];
	[root addPropertyDescription: identity];

	[other setParent: root];

	UKObjectsEqual(S(identity, title, authors), SA([book allPropertyDescriptions]));
}

- (void) testBasic
{
	/*id book = [ETEntityDescription descriptionWithName: @"Book"];
	id title = [ETPropertyDescription descriptionWithName: @"title"];
	id authors = [ETPropertyDescription descriptionWithName: @"authors"];*/
	[authors setMultivalued: YES];
	[book setPropertyDescriptions: A(title, authors)];
	
	id person = [ETEntityDescription descriptionWithName: @"Person"];
	id name = [ETPropertyDescription descriptionWithName: @"name"];
	id personBooks = [ETPropertyDescription descriptionWithName: @"books"];
	[personBooks setMultivalued: YES];
	[person setPropertyDescriptions: A(name, personBooks)];

	id library = [ETEntityDescription descriptionWithName: @"Library"];
	id librarian = [ETPropertyDescription descriptionWithName: @"librarian"];
	id libraryBooks = [ETPropertyDescription descriptionWithName: @"books"];
	[libraryBooks setMultivalued: YES];
	[library setPropertyDescriptions: A(librarian, libraryBooks)];

	[authors setOpposite: personBooks];

	UKObjectsEqual(SA([book propertyDescriptions]), S(title, authors));
	UKObjectsEqual(SA([person propertyDescriptions]), S(name, personBooks));	
	UKObjectsEqual(SA([library propertyDescriptions]), S(librarian, libraryBooks));
	
	// Test that the opposite relationship is bidirectional
	UKObjectsEqual([personBooks opposite], authors);

	NSMutableArray *warnings = [NSMutableArray array];

	/*[book checkConstraints: warnings];
	[person checkConstraints: warnings];
	[library checkConstraints: warnings];*/
	ETLog(@"Check constraint warnings: %@", warnings);
	
	// FIXME: UKTrue([warnings isEmpty]);
}

@end
