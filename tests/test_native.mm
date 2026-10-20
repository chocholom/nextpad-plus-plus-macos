#import <Cocoa/Cocoa.h>
#import "EditorView.h"
#import "NppApplication.h"
#import "MainWindowController.h"
#import "TabManager.h"
#import "NppTabBar.h"
#import "SearchResultsPanel.h"
#import "NppAPICompletion.h"
#import "NppFileFilter.h"
#import "NppParserRegex.h"
#import "NppCommandDispatch.h"
#import "NppPaths.h"
#import "NppPluginManager.h"
#import "NppPluginInterfaceMac.h"
#import "NppModelXmlMerge.h"
#import "NppLangsManager.h"
#import "UserDefineLangManager.h"
#import "DocumentMapPanel.h"
#import "StyleConfiguratorWindowController.h"
#import "ShortcutMapperWindowController.h"
#import "NppThemeManager.h"
#import "PreferencesWindowController.h"
#import "MenuBuilder.h"
#import "AppDelegate.h"
#import "NppCommandLineParams.h"
#include "Scintilla.h"
#include <sys/stat.h>

@interface AppDelegate (Testing)
- (void)_forwardedCommandLine:(NSNotification *)notification;
@end
@interface NppPluginManager (Testing)
- (intptr_t)handleNppMessage:(uint32_t)message wParam:(uintptr_t)wp lParam:(intptr_t)lp;
@end
@interface SearchResultsPanel (Testing)
- (void)_copyLines:(id)sender;
@end
@interface MainWindowController (Testing)
- (void)saveSessionToPath:(NSString *)path;
- (void)updateStatusBar;
- (NSArray<EditorView *> *)allOpenEditors;
- (void)restoreRecentClosedFile:(id)sender;
- (BOOL)tabManagerShouldExitOnLastTabClose:(id)manager;
@end
@interface EditorView (Testing)
- (void)applyDefaultTheme;
@end

static int failures, checks;
static void check(BOOL condition, NSString *name) {
    checks++; printf("[%s] %s\n",condition?"PASS":"FAIL",name.UTF8String);
    if(!condition)failures++;
}
static EditorView *editor(void) { return [[EditorView alloc] initWithFrame:NSMakeRect(0,0,900,600)]; }
static NSString *text(ScintillaView *sci) { return sci.string; }
static void pump(void) {
    for(int i=0;i<4;i++) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

int main(void) { @autoreleasepool {
    setbuf(stdout,NULL);
    NSPasteboard *clipboard=NSPasteboard.generalPasteboard;
    NSMutableArray<NSDictionary *> *clipboardSnapshot=[NSMutableArray new];
    for(NSPasteboardItem *item in clipboard.pasteboardItems) {
        NSMutableDictionary *values=[NSMutableDictionary new];
        for(NSPasteboardType type in item.types) { NSData *value=[item dataForType:type];if(value)values[type]=value; }
        [clipboardSnapshot addObject:values];
    }
    NSInteger clipboardOwnedChange=-1;
    NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"nextpad-native-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    NppSetConfigDirOverride([root stringByAppendingPathComponent:@"profile"]);
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    [NppApplication sharedApplication];
    NppInstallUserLangsAndStylers();
    [[NppLangsManager shared] loadLangs];
    [MenuBuilder buildMainMenu];
    [NSUserDefaults.standardUserDefaults registerDefaults:@{kPrefEOLType:@1,kPrefTabCloseButton:@YES,kPrefAutoCompleteEnable:@NO,kPrefLargeFileEnabled:@NO,kPrefTabWidth:@4}];
    @try {
        for (NSString *ending in @[@"\r\n",@"\r",@"\n"]) {
            NSString *path=[root stringByAppendingPathComponent:@"eol.txt"];
            NSString *input=[NSString stringWithFormat:@"one%@two%@",ending,ending];
            [input writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            EditorView *ed=editor(); check([ed loadFileAtPath:path error:nil],@"load EOL fixture");
            int mode=[ending isEqual:@"\r\n"]?SC_EOL_CRLF:[ending isEqual:@"\r"]?SC_EOL_CR:SC_EOL_LF;
            check([ed.scintillaView message:SCI_GETEOLMODE]==mode,@"detect file EOL");
            [ed applyDefaultTheme];
            check([ed.scintillaView message:SCI_GETEOLMODE]==mode,@"theme preserves EOL");
            [ed.scintillaView message:SCI_DOCUMENTEND]; [ed.scintillaView message:SCI_NEWLINE];
            NSString *output=[root stringByAppendingPathComponent:@"saved.txt"];
            check([ed saveToPath:output error:nil],@"save edited EOL fixture");
            NSData *saved=[NSData dataWithContentsOfFile:output];
            check([saved isEqual:[[input stringByAppendingString:ending] dataUsingEncoding:NSUTF8StringEncoding]],@"Enter and save preserve exact EOL bytes");
            EditorView *clone=editor();[clone shareDocumentFrom:ed];[clone applyDefaultTheme];
            check([ed.scintillaView message:SCI_GETEOLMODE]==mode,@"clone theme preserves shared EOL");
        }
        for (NSNumber *pref in @[@0,@1,@2]) {
            [NSUserDefaults.standardUserDefaults setInteger:pref.integerValue forKey:kPrefEOLType];
            EditorView *ed=editor(); int expected=pref.intValue==0?SC_EOL_CRLF:pref.intValue==2?SC_EOL_CR:SC_EOL_LF;
            check([ed.scintillaView message:SCI_GETEOLMODE]==expected,@"new document uses EOL preference");
        }
        [NSUserDefaults.standardUserDefaults setInteger:1 forKey:kPrefEOLType];
        EditorView *ed=editor();ScintillaView *sci=ed.scintillaView;
        sci.string=@"World World";
        [sci message:SCI_SETSELECTION wParam:5 lParam:0];[sci message:SCI_ADDSELECTION wParam:11 lParam:6];
        [ed convertToLowercase:nil];check([text(sci) isEqual:@"world world"],@"lowercase preserves two selections");
        [ed convertToUppercase:nil];check([text(sci) isEqual:@"WORLD WORLD"],@"uppercase preserves two selections");
        [sci message:SCI_UNDO];check([text(sci) isEqual:@"world world"],@"case conversion is one undo action");
        sci.string=@"z 1\nx 3\ny 2\n";
        [sci message:SCI_SETSELECTIONMODE wParam:SC_SEL_RECTANGLE];
        [sci message:SCI_SETRECTANGULARSELECTIONANCHOR wParam:2];[sci message:SCI_SETRECTANGULARSELECTIONCARET wParam:11];
        [ed sortLinesIntAsc:nil];check([text(sci) isEqual:@"z 1\ny 2\nx 3\n"],@"numeric rectangular sort uses selected column and moves whole rows");
        [sci message:SCI_UNDO];check([text(sci) isEqual:@"z 1\nx 3\ny 2\n"],@"column sort undo restores exact bytes");

        NppAPICompletion *api=[NppAPICompletion completionForLanguage:@"c"];
        check([[api wordsWithPrefix:@"prin"] containsObject:@"printf"],@"bundled C API completion works without document words");
        NSRange highlight;NSString *signature=[api signatureForFunction:@"printf" overload:0 parameter:0 highlight:&highlight];
        check([signature containsString:@"printf"] && signature.length > 15,@"real API signature loaded");
        check(highlight.length>0,@"signature exposes active parameter byte range");
        [ed setLanguage:@"c"];sci.string=@"printf(\"%d\", ";[sci message:SCI_DOCUMENTEND];
        [ed triggerFunctionParametersHint:nil];check([sci message:SCI_CALLTIPACTIVE],@"native editor shows real parameter hint");

        SearchResultsPanel *panel=[[SearchResultsPanel alloc] initWithFrame:NSMakeRect(0,0,900,300)];
        NPPFileResults *file=[NPPFileResults new];file.filePath=@"fixture.txt";
        NPPSearchResult *result=[NPPSearchResult new];result.filePath=file.filePath;result.lineNumber=7;result.lineText=@"hello: Line 9: café";result.matchStart=0;result.matchLength=5;
        [file.results addObject:result];NPPFindOptions *opts=[NPPFindOptions new];opts.searchText=@"hello";
        [panel addResults:@[file] forSearchText:@"hello" options:opts filesSearched:1];
        ScintillaView *results=[panel valueForKey:@"sci"];
        [results message:SCI_GOTOLINE wParam:2];[panel _copyLines:nil];clipboardOwnedChange=clipboard.changeCount;
        check([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqual:@"hello: Line 9: café\n"],@"copy results excludes only generated metadata");
        [panel addResults:@[] forSearchText:@"absent" options:opts filesSearched:3];
        check([results.string containsString:@"Search \"absent\" (0 hits"],@"zero-hit search adds its own history header");
        [panel setValue:@YES forKey:@"purgeBeforeSearch"];
        [panel addResults:@[] forSearchText:@"fresh" options:opts filesSearched:3];
        check(![results.string containsString:@"hello"] && [results.string containsString:@"fresh"],@"zero-hit search obeys purge");
        check([results message:SCI_GETSCROLLWIDTHTRACKING],@"search result horizontal width tracking enabled");

        NppFileFilter *filter=[[NppFileFilter alloc] initWithString:@"*.* !*.log !\\build !+\\node_modules"];
        check([filter matchesFileName:@"README"] && ![filter matchesFileName:@"error.log"],@"extensionless filenames and file exclusions");
        check([filter excludesDirectory:@"build"] && ![filter excludesDirectory:@"src/build"] && [filter excludesDirectory:@"src/node_modules/pkg"],@"root-only and recursive directory exclusions");
        check([[[NppFileFilter alloc] initWithString:@"*.c;*.h"] matchesFileName:@"a.h"],@"semicolon-separated filters");
        NSError *error=nil;
        NppParserRegex *regex=[NppParserRegex regularExpressionWithPattern:@"(?<=prefix)\\K(?<name>café)" options:0 error:&error];
        NSTextCheckingResult *match=[regex firstMatchInString:@"😀prefixcafé" options:0 range:NSMakeRange(0,12)];
        check(regex && match && [[@"😀prefixcafé" substringWithRange:match.range] isEqual:@"café"],@"Function List Boost captures preserve UTF-16 positions after astral text");
        regex=[NppParserRegex regularExpressionWithPattern:@"(?(DEFINE)(?<word>[a-z]+))(?&word)" options:0 error:&error];
        check(regex && [regex firstMatchInString:@"hello" options:0 range:NSMakeRange(0,5)],@"Function List supports named subroutines");
        check([NppSelectorForCommand(42016) isEqual:@"convertToUppercase:"] && [NppSelectorForCommand(42046) isEqual:@"tabsToSpaces:"] && !NppSelectorForCommand(-1),@"plugins and macros share command IDs and reject unknown IDs");

        NppTabBar *bar=[[NppTabBar alloc] initWithFrame:NSMakeRect(0,0,700,30)];
        [bar addTabWithTitle:@"one.txt" modified:NO];[bar addTabWithTitle:@"two.txt" modified:YES];
        NSArray *tabs=[bar accessibilityChildren];
        check([[bar accessibilityRole] isEqual:NSAccessibilityTabGroupRole] && tabs.count==2,@"VoiceOver sees tab group and tabs");
        check([[[tabs[1] accessibilityChildren] firstObject] accessibilityPerformPress],@"VoiceOver close action available");

        // Integration checks for the existing language, map and plugin PRs.
        NppPluginManager *plugins=[NppPluginManager shared];
        int marker=-1,indicator=-1;
        check([plugins handleNppMessage:NPPM_ALLOCATEMARKER wParam:14 lParam:(intptr_t)&marker] && marker==1,@"plugins receive only marker IDs 1 through 14");
        int denied=99;
        check(![plugins handleNppMessage:NPPM_ALLOCATEMARKER wParam:1 lParam:(intptr_t)&denied] && denied==0 && [plugins handleNppMessage:NPPM_GETBOOKMARKID wParam:0 lParam:0]==20,@"marker exhaustion leaves bookmark and fold IDs reserved");
        check([plugins handleNppMessage:NPPM_ALLOCATEINDICATOR wParam:12 lParam:(intptr_t)&indicator] && indicator==9,@"plugins receive only indicator IDs 9 through 20");
        denied=99;check(![plugins handleNppMessage:NPPM_ALLOCATEINDICATOR wParam:1 lParam:(intptr_t)&denied] && denied==99,@"indicator exhaustion preserves caller sentinel");
        NppModelXmlMergeStatus mergeStatus;
        NSString *merged=NppMergeModelXmlText(@"<NotepadPlus modelDate='20200101'><Languages><Language name='c' ext='mine'><Keywords name='instre1'>custom</Keywords></Language></Languages></NotepadPlus>",
            @"<NotepadPlus modelDate='20261015'><Languages><Language name='c' ext='c'><Keywords name='instre1'>int</Keywords><Keywords name='type1'>size_t</Keywords></Language><Language name='newlang' ext='nl'/></Languages></NotepadPlus>",NppModelXmlKindLangs,NO,&mergeStatus,nil);
        check(mergeStatus==NppModelXmlMergeMerged && [merged containsString:@"custom"] && [merged containsString:@"size_t"] && [merged containsString:@"newlang"] && [merged containsString:@"mine"],@"model update adds languages and keywords while preserving customizations");
        NSString *udlPath=[root stringByAppendingPathComponent:@"native-udl.xml"];
        [@"<NotepadPlus><UserLang name='Native Test UDL' ext='c' udlVersion='2.1'><Settings><Global caseIgnored='no'/></Settings><KeywordLists><Keywords name='Keywords1'>specialword</Keywords></KeywordLists><Styles><WordsStyle name='DEFAULT' styleID='0' fgColor='101010' bgColor='FFFFFF' fontName='Menlo' fontSize='14'/><WordsStyle name='KEYWORDS1' styleID='4' fgColor='FF0000' bgColor='FFFFFF' fontStyle='1' nesting='0'/></Styles></UserLang></NotepadPlus>" writeToFile:udlPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        UserDefineLangManager *udls=[UserDefineLangManager shared];
        check([udls importFromPath:udlPath]!=nil,@"UDL is saved into user configuration");
        [udls loadAll];
        NSString *udlFile=[root stringByAppendingPathComponent:@"udl.c"];[@"specialword \n" writeToFile:udlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        EditorView *udlEd=editor();[udlEd loadFileAtPath:udlFile error:nil];
        [udlEd.scintillaView message:SCI_COLOURISE wParam:0 lParam:-1];
        check(udlEd.currentLanguageIsUDL && [udlEd.currentLanguage isEqual:@"Native Test UDL"],@"saved UDL overrides a built-in extension");
        check([udlEd.scintillaView message:SCI_GETSTYLEAT wParam:0]==4 && [udlEd.scintillaView message:SCI_STYLEGETSIZE wParam:0]==14,@"UDL keyword lexing and font size apply");
        [ed setLanguage:@"cpp"];sci.string=@"int main() { return 0; }";[sci message:SCI_COLOURISE wParam:0 lParam:-1];
        check([sci message:SCI_GETSTYLEAT wParam:0]==16,@"C++ keywords use the correct lexer slot");
        NPPStyleStore *store=NPPStyleStore.sharedStore;
        check([store stylesForExactLexer:@"c"].count && [store stylesForExactLexer:@"objc"].count && [store stylesForExactLexer:@"typescript"].count,@"C, Objective-C and TypeScript have distinct style models");
        NppLangDef *cpp=[[NppLangsManager shared] langDefForName:@"cpp"];
        cpp.keywords[@"substyle1"]=@"my_custom_type";
        [ed setLanguage:@"cpp"];sci.string=@"my_custom_type value;\n";[sci message:SCI_COLOURISE wParam:0 lParam:-1];
        check([sci message:SCI_GETSTYLEINDEXAT wParam:0]>=128,@"substyle keywords reach the lexer");
        DocumentMapPanel *map=[[DocumentMapPanel alloc] initWithFrame:NSMakeRect(0,0,160,300)];[map setTrackedEditor:ed];
        ScintillaView *mapSci=[map valueForKey:@"mapSci"];
        check([mapSci message:SCI_GETDOCPOINTER]==[sci message:SCI_GETDOCPOINTER] && ![sci message:SCI_GETREADONLY],@"Document Map shares syntax state without making the document read-only");
        check([mapSci message:SCI_STYLEGETFORE wParam:5]==[sci message:SCI_STYLEGETFORE wParam:5],@"Document Map mirrors keyword colours");
        check([[NppThemeManager appearanceForBackground:NSColor.blackColor].name isEqual:NSAppearanceNameDarkAqua] && [[NppThemeManager appearanceForBackground:NSColor.whiteColor].name isEqual:NSAppearanceNameAqua],@"panel appearance follows its background");
        [map setTrackedEditor:nil];check([mapSci message:SCI_GETDOCPOINTER]!=[sci message:SCI_GETDOCPOINTER],@"closing Document Map releases the tracked document");

        NSString *sessionFile=[root stringByAppendingPathComponent:@"session.plist"], *source=[root stringByAppendingPathComponent:@"session.c"];
        [@"int main() {\n return 0;\n}\n" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:nil];
        MainWindowController *window=[MainWindowController new];EditorView *sessionEd=[window openFileAtPath:source];
        [sessionEd.scintillaView message:SCI_SETSEL wParam:2 lParam:8];[sessionEd.scintillaView message:SCI_MARKERADD wParam:1 lParam:20];
        [window saveSessionToPath:sessionFile];
        NSDictionary *snapshot=[NSDictionary dictionaryWithContentsOfFile:sessionFile];NSDictionary *saved=snapshot[@"tabs"][0];
        check([saved[@"selections"] count]==1 && [saved[@"bookmarks"] isEqual:@[@1]],@"named session records selection and bookmarks");
        [sessionEd.scintillaView message:SCI_SETSEL wParam:0 lParam:0];[sessionEd.scintillaView message:SCI_MARKERDELETEALL wParam:20];
        [window loadSessionFromPath:sessionFile];
        check([sessionEd.scintillaView message:SCI_GETANCHOR]==2 && [sessionEd.scintillaView message:SCI_GETCURRENTPOS]==8 && ([sessionEd.scintillaView message:SCI_MARKERGET wParam:1]&(1<<20)),@"named session restores selection and bookmarks");
        [sessionEd.scintillaView message:SCI_SETZOOM wParam:8];[window updateStatusBar];
        NSTextField *status=[window valueForKey:@"statusLeft"];
        check(status.font.pointSize==19,@"status font follows editor zoom");
        TabManager *manager=[window valueForKey:@"tabManager"];
        [plugins setMainWindowController:window];
        [manager closeEditor:sessionEd];[window restoreRecentClosedFile:nil];
        check([window.currentEditor.filePath isEqual:source],@"recently closed file reopens");
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:kPrefExitOnCloseLastTab];
        TabManager *emptyManager=[TabManager new];[emptyManager addNewTab];[emptyManager closeCurrentTab];
        check(emptyManager.allEditors.count==1,@"closing the last tab leaves a blank tab when exit is disabled");
        // Dispatch through the plugin message bridge, not only its lookup table.
        EditorView *commandEditor=window.currentEditor;
        commandEditor.scintillaView.string=@"word";
        [commandEditor.scintillaView message:SCI_SELECTALL];
        check([plugins handleNppMessage:NPPM_MENUCOMMAND wParam:0 lParam:42016],@"plugin bridge accepts a mapped Windows menu command");
        pump();check([commandEditor.scintillaView.string isEqual:@"WORD"],@"plugin menu command reaches the active editor");
        check(![plugins handleNppMessage:NPPM_MENUCOMMAND wParam:0 lParam:999999],@"plugin bridge rejects an unknown command");
        NppThemeManager *theme=[NppThemeManager shared];
        theme.mode=NppDarkModeDark;[store syncThemeWithAppearance];
        check([store.activeThemeName isEqual:[store themeNameForDarkAppearance:YES]] && [NppThemeManager isDarkColor:store.globalBg],@"dark mode selects the remembered dark editor theme");
        theme.mode=NppDarkModeLight;[store syncThemeWithAppearance];
        check([store.activeThemeName isEqual:[store themeNameForDarkAppearance:NO]] && ![NppThemeManager isDarkColor:store.globalBg],@"light mode restores the remembered light editor theme");
        // Session snapshots preserve unsaved contents and never replace a
        // conflicting modified buffer already open in this window.
        EditorView *unsaved=[manager addNewTab];unsaved.customTabName=@"scratch";
        unsaved.scintillaView.string=@"untitled café\n";
        EditorView *original=nil;
        for(EditorView *candidate in manager.allEditors) if([candidate.filePath isEqual:source]) { original=candidate;break; }
        NSString *originalSnapshot=original.scintillaView.string;
        [window saveSessionToPath:sessionFile];
        NSDictionary *withUntitled=[NSDictionary dictionaryWithContentsOfFile:sessionFile];
        check([withUntitled[@"tabs"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,NSDictionary *bindings){return [item[@"displayName"] isEqual:@"scratch"] && [item[@"content"] length]>0;}]].count==1,@"named session snapshots unsaved text");
        MainWindowController *restored=[MainWindowController new];[restored loadSessionFromPath:sessionFile];
        BOOL foundScratch=NO;for(EditorView *candidate in [restored allOpenEditors]) if([candidate.scintillaView.string isEqual:@"untitled café\n"] && !candidate.filePath.length) foundScratch=YES;
        check(foundScratch,@"named session restores untitled text without a backing file");
        original.scintillaView.string=@"newer unsaved text";
        [window loadSessionFromPath:sessionFile];
        BOOL restoredConflictCopy=NO;
        for(EditorView *candidate in manager.allEditors) if(candidate!=original && !candidate.filePath.length && [candidate.scintillaView.string isEqual:originalSnapshot]) restoredConflictCopy=YES;
        check(original && [original.scintillaView.string isEqual:@"newer unsaved text"] && restoredConflictCopy,@"named session preserves a modified file and restores the conflicting snapshot separately");
        EditorView *rect=[manager addNewTab];rect.scintillaView.string=@"one\ntwo\nthree\n";
        [rect.scintillaView message:SCI_SETSELECTIONMODE wParam:SC_SEL_RECTANGLE];
        [rect.scintillaView message:SCI_SETRECTANGULARSELECTIONANCHOR wParam:1];
        [rect.scintillaView message:SCI_SETRECTANGULARSELECTIONCARET wParam:6];
        [rect.scintillaView message:SCI_SETRECTANGULARSELECTIONCARETVIRTUALSPACE wParam:2];
        rect.customTabName=@"rectangle";
        [window saveSessionToPath:sessionFile];
        MainWindowController *rectored=[MainWindowController new];[rectored loadSessionFromPath:sessionFile];
        BOOL restoredRectangle=NO;
        for(EditorView *candidate in [rectored allOpenEditors]) if([candidate.customTabName isEqual:@"rectangle"])
            restoredRectangle=[candidate.scintillaView message:SCI_GETSELECTIONMODE]==SC_SEL_RECTANGLE && [candidate.scintillaView message:SCI_GETRECTANGULARSELECTIONANCHOR]==1 && [candidate.scintillaView message:SCI_GETRECTANGULARSELECTIONCARET]==6 && [candidate.scintillaView message:SCI_GETRECTANGULARSELECTIONCARETVIRTUALSPACE]==2;
        check(restoredRectangle,@"named session restores rectangular anchors and virtual space");
        TabManager *axManager=[TabManager new];[axManager addNewTab];[axManager addNewTab];
        NSArray *axTabs=axManager.tabBar.accessibilityChildren;
        check([axTabs[0] accessibilityPerformPress] && axManager.tabBar.selectedIndex==0,@"VoiceOver press selects the requested tab");
        check([[[axTabs[1] accessibilityChildren] firstObject] accessibilityPerformPress] && axManager.allEditors.count==1,@"VoiceOver close removes the requested tab");
        check([[axTabs[0] accessibilityHelp] containsString:@"of 1"],@"VoiceOver announces tab position and count");
        EditorView *unicode=editor();unicode.scintillaView.string=@"ß é 😀";
        [unicode.scintillaView message:SCI_SETSEL wParam:0 lParam:[unicode.scintillaView message:SCI_GETLENGTH]];
        [unicode convertToInvertedCase:nil];
        check([unicode.scintillaView.string isEqual:@"SS É 😀"],@"Unicode inverse case handles expansion and emoji");
        [unicode.scintillaView message:SCI_UNDO];check([unicode.scintillaView.string isEqual:@"ß é 😀"],@"Unicode case transformation is one undo action");
        EditorView *keys=editor();keys.scintillaView.string=@"one two";
        [keys.scintillaView message:SCI_DOCUMENTEND];
        NSString *left=[NSString stringWithFormat:@"%C",(unichar)NSLeftArrowFunctionKey];
        NSEvent *wordLeft=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagOption|NSEventModifierFlagShift timestamp:0 windowNumber:0 context:nil characters:left charactersIgnoringModifiers:left isARepeat:NO keyCode:123];
        [keys.scintillaView.content keyDown:wordLeft];
        check([[keys selectedText] isEqual:@"two"],@"Option-Shift-Left selects a word through Cocoa key handling");
        NSMenuItem *plus=[NSMenuItem new],*minus=[NSMenuItem new];
        NppApplyShortcutToMenuItem(plus,187,YES,NO,NO,NO);NppApplyShortcutToMenuItem(minus,189,YES,NO,NO,NO);
        check([plus.keyEquivalent isEqual:@"="] && [minus.keyEquivalent isEqual:@"-"],@"shortcut mapper supports plus and minus menu equivalents");
        // Issue #267: verify persisted Scintilla scroll shortcuts through
        // Cocoa key dispatch rather than invoking SCI_LINESCROLL directly.
        NSString *shortcuts=NppConfigSubpath(@"shortcuts.xml");NSData *oldShortcuts=[NSData dataWithContentsOfFile:shortcuts];
        [@"<NotepadPlus><ScintillaKeys><ScintKey ScintID='2342' Key='74' Cmd='no' Ctrl='yes' Alt='yes' Shift='no'/><ScintKey ScintID='2343' Key='75' Cmd='no' Ctrl='yes' Alt='yes' Shift='no'/></ScintillaKeys></NotepadPlus>" writeToFile:shortcuts atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [keys applyScintillaKeyOverrides];
        keys.scintillaView.string=[@"line\n" stringByPaddingToLength:1500 withString:@"line\n" startingAtIndex:0];
        [keys layoutSubtreeIfNeeded];[keys.scintillaView message:SCI_SETFIRSTVISIBLELINE wParam:20];
        sptr_t first=[keys.scintillaView message:SCI_GETFIRSTVISIBLELINE];
        NSEvent *scrollDown=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagControl|NSEventModifierFlagOption timestamp:0 windowNumber:0 context:nil characters:@"j" charactersIgnoringModifiers:@"j" isARepeat:NO keyCode:38];
        [keys.scintillaView.content keyDown:scrollDown];
        check([keys.scintillaView message:SCI_GETFIRSTVISIBLELINE]==first+1,@"persisted SCI_LINESCROLLDOWN shortcut scrolls through Cocoa key handling");
        NSEvent *scrollUp=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagControl|NSEventModifierFlagOption timestamp:0 windowNumber:0 context:nil characters:@"k" charactersIgnoringModifiers:@"k" isARepeat:NO keyCode:40];
        [keys.scintillaView.content keyDown:scrollUp];
        check([keys.scintillaView message:SCI_GETFIRSTVISIBLELINE]==first,@"persisted SCI_LINESCROLLUP shortcut scrolls through Cocoa key handling");
        if(oldShortcuts) [oldShortcuts writeToFile:shortcuts atomically:YES];
        // Exercise the receiver against the real controller and the sender in
        // a second process, with the same private bundle ID as this test app.
        NSString *cliFile=[root stringByAppendingPathComponent:@"from cli.py"];
        [@"one\ntwothree\n" writeToFile:cliFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        AppDelegate *delegate=[AppDelegate new];delegate.mainWindowController=window;
        [delegate _forwardedCommandLine:[NSNotification notificationWithName:@"test" object:nil userInfo:@{@"arguments":@[@"nextpad++",@"-n2",@"-c3",@"-lpython",cliFile]}]];
        pump();
        check([window.currentEditor.filePath isEqual:cliFile] && [window.currentEditor.currentLanguage isEqual:@"python"] && [window.currentEditor.scintillaView message:SCI_GETCURRENTPOS]==6,@"forwarded CLI opens file with language, line and column");
        NSString *probe=NSProcessInfo.processInfo.environment[@"NEXTPAD_CLI_PROBE"];
        NSString *notificationName=[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".OpenCommandLine"];
        __block NSArray *received=nil;
        id observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:notificationName object:[NSString stringWithFormat:@"%d",getpid()] queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ received=note.userInfo[@"arguments"]; }];
        NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:probe];task.currentDirectoryURL=[NSURL fileURLWithPath:root];
        task.arguments=@[@"-n2",@"-lpython",@"from cli.py"];
        NSMutableDictionary *environment=[NSProcessInfo.processInfo.environment mutableCopy];environment[@"NEXTPAD_SETTINGS_DIR"]=[root stringByAppendingPathComponent:@"cli-fallback"];task.environment=environment;
        [task launchAndReturnError:nil];
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
        while ((!received || task.running) && deadline.timeIntervalSinceNow>0) pump();
        if (task.running) [task terminate];
        struct stat wanted={},actual={};
        BOOL sameFile=received && stat(cliFile.fileSystemRepresentation,&wanted)==0 && stat([received.lastObject fileSystemRepresentation],&actual)==0 && wanted.st_dev==actual.st_dev && wanted.st_ino==actual.st_ino;
        if(!sameFile) NSLog(@"CLI probe received %@ (expected %@), running=%d",received,cliFile,task.running);
        check(sameFile && [received containsObject:@"-n2"] && !task.running && task.terminationStatus==0,@"real CLI binary forwards relative paths and flags into a running instance");
        [NSDistributedNotificationCenter.defaultCenter removeObserver:observer];
        const char *injected[]={"nextpad++","-ApplePersistenceIgnoreState","YES","-NSDocumentRevisionsDebugMode","YES",cliFile.UTF8String};
        NppCommandLineParams *parsed=[[NppCommandLineParams alloc] initWithArgc:6 argv:injected];
        check([parsed.filePaths isEqual:@[cliFile]],@"macOS injected argument values do not open bogus YES files");
        pump();
    } @catch(NSException *e) { check(NO,[NSString stringWithFormat:@"uncaught %@: %@",e.name,e.reason]); }
    printf("%d checks, %d failures\n",checks,failures);
    // All persistent state is confined to this test's profile and defaults domain.
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    if(clipboardOwnedChange==clipboard.changeCount) {
        NSMutableArray *items=[NSMutableArray new];
        for(NSDictionary *values in clipboardSnapshot) {
            NSPasteboardItem *item=[NSPasteboardItem new];
            for(NSPasteboardType type in values) [item setData:values[type] forType:type];
            [items addObject:item];
        }
        [clipboard clearContents];if(items.count)[clipboard writeObjects:items];
    }
    return failures?1:0;
} }
