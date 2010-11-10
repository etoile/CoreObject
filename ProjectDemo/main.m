#import <Cocoa/Cocoa.h>
#import <ExceptionHandling/NSExceptionHandler.h>

int main(int argc, char *argv[])
{
	// [[NSExceptionHandler defaultExceptionHandler]
	//setExceptionHandlingMask:NSLogAndHandleEveryExceptionMask];
	//[[NSExceptionHandler defaultExceptionHandler]
	//setExceptionHangingMask: NSHangOnTopLevelExceptionMask | NSHangOnOtherExceptionMask];
	
    return NSApplicationMain(argc,  (const char **) argv);
}
