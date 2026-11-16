#!/usr/bin/env python3
"""Generate the small, dependency-free Xcode project deterministically."""
import hashlib
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "UdaimaniaCaptureLab.xcodeproj"
objects = {}

def key(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()

def obj(label, **fields):
    identifier = key(label)
    objects[identifier] = fields
    return identifier

def file(path, kind):
    return obj("file:" + path, isa="PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="<group>")

def encode(value):
    if isinstance(value, dict):
        return "{\n" + "".join(f"\t{json.dumps(str(k))} = {encode(v)};\n" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v) for v in value) + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value))

app_sources = sorted((ROOT / "CaptureLab").glob("*.swift"))
source_refs = {p: file(str(p.relative_to(ROOT)), "sourcecode.swift") for p in app_sources}
report_ref = file("UsageReport/UsageReport.swift", "sourcecode.swift")
fixture_ref = file("TestScenes/TestScenesApp.swift", "sourcecode.swift")
config_ref = file("Config/Base.xcconfig", "text.xcconfig")
package = obj("package", isa="XCLocalSwiftPackageReference", relativePath="CaptureCore")
products = []
targets = []

def configurations(label, settings):
    configs = []
    for mode in ["Debug", "Release"]:
        effective = dict(settings)
        effective.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if mode == "Debug" else "-O",
                         DEBUG_INFORMATION_FORMAT="dwarf" if mode == "Debug" else "dwarf-with-dsym")
        configs.append(obj(label + mode, isa="XCBuildConfiguration", baseConfigurationReference=config_ref,
                           buildSettings=effective, name=mode))
    return obj(label + "configs", isa="XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Debug")

base = dict(SDKROOT="iphoneos", IPHONEOS_DEPLOYMENT_TARGET="27.0", SWIFT_VERSION="5.0",
            CLANG_ENABLE_MODULES="YES", SWIFT_STRICT_CONCURRENCY="complete",
            TARGETED_DEVICE_FAMILY="1", SUPPORTED_PLATFORMS="iphoneos iphonesimulator",
            CODE_SIGN_STYLE="Automatic", DEVELOPMENT_TEAM="$(CAPTURE_LAB_TEAM)",
            CURRENT_PROJECT_VERSION="1", MARKETING_VERSION="0.1.0",
            GENERATE_INFOPLIST_FILE="NO", ENABLE_USER_SCRIPT_SANDBOXING="YES")

def target(name, bundle, refs, info, extension=False, screen_time=False):
    product = obj(name + "product", isa="PBXFileReference", explicitFileType="wrapper.app-extension" if extension else "wrapper.application",
                  includeInIndex=0, path=name + (".appex" if extension else ".app"), sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    sources = obj(name + "sources", isa="PBXSourcesBuildPhase", buildActionMask=2147483647,
                  files=[obj(name + str(i), isa="PBXBuildFile", fileRef=ref) for i, ref in enumerate(refs)],
                  runOnlyForDeploymentPostprocessing=0)
    dependencies = []
    framework_files = []
    if not extension:
        dependency = obj(name + "core", isa="XCSwiftPackageProductDependency", package=package, productName="CaptureCore")
        dependencies.append(dependency)
        framework_files.append(obj(name + "corelink", isa="PBXBuildFile", productRef=dependency))
    frameworks = obj(name + "frameworks", isa="PBXFrameworksBuildPhase", buildActionMask=2147483647,
                     files=framework_files, runOnlyForDeploymentPostprocessing=0)
    settings = dict(base, PRODUCT_NAME=name, PRODUCT_BUNDLE_IDENTIFIER=bundle, INFOPLIST_FILE=info,
                    CAPTURE_LAB_DISPLAY_NAME="Udaimania Usage" if screen_time else "Udaimania Lab",
                    LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks"])
    if extension:
        settings.update(APPLICATION_EXTENSION_API_ONLY="YES", SKIP_INSTALL="YES")
        settings["LD_RUNPATH_SEARCH_PATHS"].append("@executable_path/../../Frameworks")
    if screen_time:
        settings.update(CODE_SIGN_ENTITLEMENTS="Config/ScreenTime.entitlements",
                        SWIFT_ACTIVE_COMPILATION_CONDITIONS="$(inherited) SCREEN_TIME_ENABLED")
    target_id = obj(name, isa="PBXNativeTarget", buildConfigurationList=configurations(name, settings),
                    buildPhases=[sources, frameworks], buildRules=[], dependencies=[], name=name,
                    packageProductDependencies=dependencies, productName=name, productReference=product,
                    productType="com.apple.product-type.app-extension" if extension else "com.apple.product-type.application")
    targets.append(target_id)
    return target_id, product

basic, _ = target("UdaimaniaCaptureLab", "com.udaimania.capturelab", list(source_refs.values()), "Config/App-Info.plist")
full, _ = target("UdaimaniaUsageLab", "com.udaimania.capturelab.screentime", list(source_refs.values()), "Config/App-Info.plist", screen_time=True)
fixture, _ = target("UdaimaniaTestScenes", "com.udaimania.capturelab.fixtures", [fixture_ref], "Config/Fixture-Info.plist")
report, report_product = target("UdaimaniaUsageReport", "com.udaimania.capturelab.screentime.report", [report_ref],
                                "Config/Report-Info.plist", extension=True, screen_time=True)
proxy = obj("report-proxy", isa="PBXContainerItemProxy", containerPortal=key("project"), proxyType=1,
            remoteGlobalIDString=report, remoteInfo="UdaimaniaUsageReport")
objects[full]["dependencies"] = [obj("report-dependency", isa="PBXTargetDependency", target=report, targetProxy=proxy)]
embed = obj("embed-report", isa="PBXCopyFilesBuildPhase", buildActionMask=2147483647, dstPath="", dstSubfolderSpec=13,
            files=[obj("embed-report-file", isa="PBXBuildFile", fileRef=report_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})],
            name="Embed report extension", runOnlyForDeploymentPostprocessing=0)
objects[full]["buildPhases"].append(embed)
product_group = obj("products", isa="PBXGroup", children=products, name="Products", sourceTree="<group>")
main_group = obj("main-group", isa="PBXGroup", children=list(source_refs.values()) + [report_ref, fixture_ref, config_ref, product_group], sourceTree="<group>")
project_id = obj("project", isa="PBXProject", attributes={"LastUpgradeCheck": "2720", "BuildIndependentTargetsInParallel": "YES"},
                 buildConfigurationList=configurations("project", {"ALWAYS_SEARCH_USER_PATHS": "NO"}),
                 compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings=0,
                 knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=product_group,
                 projectDirPath="", projectRoot="", targets=targets, packageReferences=[package])
PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": 1, "classes": {}, "objectVersion": 56,
                                                                 "objects": objects, "rootObject": project_id}) + "\n")
schemes = PROJECT / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
for name, identifier, product in [("Capture Lab", basic, "UdaimaniaCaptureLab"),
                                   ("Synthetic Test Scenes", fixture, "UdaimaniaTestScenes"),
                                   ("Capture Lab + Screen Time", full, "UdaimaniaUsageLab")]:
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}.app" BlueprintName="{product}" ReferencedContainer="container:UdaimaniaCaptureLab.xcodeproj"/>'
    (schemes / f"{name}.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2720" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated {PROJECT}")
