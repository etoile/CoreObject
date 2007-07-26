This Xcode project contains instructions and example code for building Blocks framework
style plugins. You should first read the general Blocks documentation here:

	http://www.hogbaysoftware.com/book/

Descriptions of folders contained in this project:

Protocols - Any plugin that you write needs to plug into an extension point provided
by some other plugin. The protocols folder contains the information needed to extend
plugins created by Hog Bay Software. Inside you'll find subfolders for each plugin, and inside
those folders you will see two files, a Protocols.h file and a plugin.xml file.

The .h file contains objective-c protocols and constants that will be availible to
your plugin if you extend the given plugin. The plugin.xml file contains extension-point
keys that your plugin will use to when extending that plugin.

Basic Example Plugins/LifeCyclePluginExample - This is a simple plugin that extends from 
the com.hogbaysoftware.lifecycle.lifecycle extension point that is defined by the 
BKLifeCycle.plugin. When placed in a Blocks based application's plugin folder the 
LifeCyclePluginExample plugin will NSLog each lifecycle event of the application.

Basic Example Plugins/UserInterfacePlugin - This is a simple plugin that extends from the
com.hogbaysoftware.ui.mainmenu extension point that is defined by the BKUserInterface.plugin.
This extension point allows other plugins to add menu items.

Clockwork Example Plugins/CWAlarmActionExample - This plugin extends from the com.hogbaysoftware.CWTimers.alarmActions 
extension point that is defined by Clockwork's BKTimers.plugin. This plugin shows
how to create a custom alarm action.

Clockwork Example Plugins/CWTalkingTimer - This plugin extends from the com.hogbaysoftware.lifecycle.lifecycle
extension point so that it is loaded when Clockwork starts. It then registers for some
Clockwork notifications and speaks the timer shown in Clockworks dock icon.

Mori Example Plugins/MIHBN35Import - This plugin extends from the com.hogbaysoftware.mori.MIDocument.entryImport
extension point and is used to import Hog Bay Notebook 3.5 files into Mori.

Mori Example Plugins/MITextFileImport - This plugin extends from the com.hogbaysoftware.mori.MIDocument.entryImport
extension point and is used to import many different text file formats into Mori.

Mori Example Plugins/MIFolderSupport - This plugin extends from the com.hogbaysoftware.mori.MIDocument.entryImport
and com.hogbaysoftware.mori.MIDocument.entryExport extension points and is used to import file system folders. And used
to export text files hierarchies in a number of different formats.

Mori Example Plugins/MIOPMLSupport - This plugin extends from the com.hogbaysoftware.mori.MIDocument.entryImport
and com.hogbaysoftware.mori.MIDocument.entryExport extension points and is used to import and export OPML files.

Blocks framework documentation needs your questions and feedback to improve. If you
have a question please post it here:

	http://www.hogbaysoftware.dreamhosters.com/forum/blocks


Thanks,
Jesse