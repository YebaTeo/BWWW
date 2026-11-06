# Legacy scaffolding: do not run over an existing signed project.
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent
p=root/'BeBaduy.xcodeproj'; p.mkdir(exist_ok=True)
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(key, value):
 i=uid(key); objects.append(f'{i} = {{ {value} }};'); return i
app=uid('app'); tests=uid('tests'); ui=uid('ui'); project=uid('project')
# Native filesystem-synchronized roots (Xcode 16+). Xcode discovers sources and
# resources directly and presents real folders and ordinary filename-only entries.
source_roots=[]
for base,target in [('BeBaduy','app'),('BeBaduyTests','tests'),('BeBaduyUITests','ui')]:
 group=obj(target+'root',f'isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {{}}; explicitFolders = (); path = "{base}"; sourceTree = "<group>";')
 source_roots.append(group)
 for phase,kind in [('sources','PBXSourcesBuildPhase'),('resources','PBXResourcesBuildPhase'),('frameworks','PBXFrameworksBuildPhase')]:
  obj(target+phase,f'isa = {kind}; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
products=[]
for target,name,ext in [('app','BeBaduy','app'),('tests','BeBaduyTests','xctest'),('ui','BeBaduyUITests','xctest')]:
 prod=obj(target+'product',f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if ext=="app" else "wrapper.cfbundle"}; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;'); products.append(prod)
 configs=[]
 for conf in ['Debug','Release']:
  settings={'PRODUCT_NAME':'"$(TARGET_NAME)"','PRODUCT_BUNDLE_IDENTIFIER':f'org.bebaduy.{name}','IPHONEOS_DEPLOYMENT_TARGET':'26.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SWIFT_VERSION':'5.0','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','SWIFT_STRICT_CONCURRENCY':'complete'}
  if target=='app': settings.update({'INFOPLIST_KEY_NSMotionUsageDescription':'"Gerakan ponsel digunakan untuk melihat lahan virtual, mencoba aseuk, dan menyeimbangkan padi. Kontrol sentuhan selalu tersedia."','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait','INFOPLIST_KEY_CFBundleDisplayName':'BeBaduy','INFOPLIST_KEY_LSApplicationCategoryType':'"public.app-category.education"','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'})
  elif target=='tests': settings.update({'TEST_HOST':'"$(BUILT_PRODUCTS_DIR)/BeBaduy.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/BeBaduy"','BUNDLE_LOADER':'"$(TEST_HOST)"'})
  else: settings['TEST_TARGET_NAME']='BeBaduy'
  if conf=='Debug': settings.update({'SWIFT_OPTIMIZATION_LEVEL':'"-Onone"','DEBUG_INFORMATION_FORMAT':'dwarf','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG'})
  else: settings['SWIFT_OPTIMIZATION_LEVEL']='"-O"'
  configs.append(obj(target+conf,'isa = XCBuildConfiguration; name = '+conf+'; buildSettings = {'+' '.join(k+' = '+v+';' for k,v in settings.items())+'};'))
 cl=obj(target+'config','isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
 deps=[]
 if target!='app':
  proxy=obj(target+'proxy',f'isa = PBXContainerItemProxy; containerPortal = {project}; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = BeBaduy;')
  deps=[obj(target+'dep',f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')]
 obj(target,f'isa = PBXNativeTarget; name = {name}; buildConfigurationList = {cl}; buildPhases = ({uid(target+"sources")},{uid(target+"frameworks")},{uid(target+"resources")}); buildRules = (); dependencies = ({",".join(deps)}); fileSystemSynchronizedGroups = ({uid(target+"root")}); productName = {name}; productReference = {prod}; productType = "com.apple.product-type.{"application" if target=="app" else "bundle.unit-test" if target=="tests" else "bundle.ui-testing"}";')
pg=obj('products','isa = PBXGroup; children = ('+','.join(products)+'); name = Products; sourceTree = "<group>";')
mg=obj('main','isa = PBXGroup; children = ('+','.join(source_roots+[pg])+'); sourceTree = "<group>";')
pcs=[obj('project'+c,f'isa = XCBuildConfiguration; name = {c}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; ENABLE_TESTABILITY = YES; }};') for c in ['Debug','Release']]
pc=obj('projectconfig','isa = XCConfigurationList; buildConfigurations = ('+','.join(pcs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {pc}; preferredProjectObjectVersion = 77; developmentRegion = id; knownRegions = (id,en,Base); mainGroup = {mg}; productRefGroup = {pg}; projectDirPath = ""; projectRoot = ""; targets = ({app},{tests},{ui});')
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 77; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=p/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
def ref(t,n): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(t)}" BuildableName="{n}.{ "app" if t=="app" else "xctest"}" BlueprintName="{n}" ReferencedContainer="container:BeBaduy.xcodeproj"/>'
(scheme/'BeBaduy.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('app','BeBaduy')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug"><Testables><TestableReference skipped="NO">{ref('tests','BeBaduyTests')}</TestableReference><TestableReference skipped="NO">{ref('ui','BeBaduyUITests')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('app','BeBaduy')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{ref('app','BeBaduy')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated BeBaduy.xcodeproj')
