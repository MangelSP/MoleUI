#!/usr/bin/env python3
"""Generate a minimal, valid project.pbxproj for the MoleUI macOS app."""
import hashlib, os, sys

ROOT = "/Users/usuario/repos/mole-app/MoleUI"
SRC_GROUP = "MoleUI"          # folder containing sources, relative to project root
src_dir = os.path.join(ROOT, SRC_GROUP)

def uid(*parts):
    h = hashlib.md5("::".join(parts).encode()).hexdigest().upper()
    return h[:24]

# Collect .swift files (relative to the source group dir), sorted for determinism.
swift = []
for dirpath, _, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".swift"):
            rel = os.path.relpath(os.path.join(dirpath, f), src_dir)
            swift.append(rel)
swift.sort()

# Fixed object IDs
PROJECT      = uid("project")
MAIN_GROUP   = uid("mainGroup")
SRC_GROUP_ID = uid("srcGroup")
PRODUCTS_GRP = uid("products")
TARGET       = uid("target")
PRODUCT_REF  = uid("productRef")          # MoleUI.app
SOURCES_PH   = uid("sourcesPhase")
FRAMEWORKS_PH= uid("frameworksPhase")
RESOURCES_PH = uid("resourcesPhase")
PROJ_CFG_LIST= uid("projCfgList")
TARG_CFG_LIST= uid("targCfgList")
PROJ_DEBUG   = uid("projDebug")
PROJ_RELEASE = uid("projRelease")
TARG_DEBUG   = uid("targDebug")
TARG_RELEASE = uid("targRelease")
ASSETS_REF   = uid("assetsRef")
ASSETS_BUILD = uid("assetsBuild")

has_assets = os.path.isdir(os.path.join(src_dir, "Assets.xcassets"))

# Per-file IDs
file_ref = {rel: uid("ref", rel) for rel in swift}
build_ref = {rel: uid("build", rel) for rel in swift}

def file_ref_lines():
    out = []
    for rel in swift:
        name = os.path.basename(rel)
        out.append(f'\t\t{file_ref[rel]} /* {name} */ = {{isa = PBXFileReference; '
                   f'lastKnownFileType = sourcecode.swift; name = "{name}"; '
                   f'path = "{rel}"; sourceTree = "<group>"; }};')
    return "\n".join(out)

def build_file_lines():
    out = []
    for rel in swift:
        name = os.path.basename(rel)
        out.append(f'\t\t{build_ref[rel]} /* {name} in Sources */ = {{isa = PBXBuildFile; '
                   f'fileRef = {file_ref[rel]} /* {name} */; }};')
    return "\n".join(out)

def group_children():
    lines = [f'\t\t\t\t{file_ref[rel]} /* {os.path.basename(rel)} */,' for rel in swift]
    if has_assets:
        lines.append(f'\t\t\t\t{ASSETS_REF} /* Assets.xcassets */,')
    return "\n".join(lines)

def sources_phase_files():
    return "\n".join(f'\t\t\t\t{build_ref[rel]} /* {os.path.basename(rel)} in Sources */,' for rel in swift)

COMMON_BUILD = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_ENTITLEMENTS = "MoleUI/MoleUI.entitlements";
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "MoleUI/Info.plist";
				INFOPLIST_KEY_NSMainStoryboardFile = "";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.moleui.app";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;"""

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_file_lines()}
{f'		{ASSETS_BUILD} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS_REF} /* Assets.xcassets */; }};' if has_assets else ''}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{PRODUCT_REF} /* MoleUI.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "MoleUI.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
{file_ref_lines()}
{f'		{ASSETS_REF} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "Assets.xcassets"; sourceTree = "<group>"; }};' if has_assets else ''}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{FRAMEWORKS_PH} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{MAIN_GROUP} = {{
			isa = PBXGroup;
			children = (
				{SRC_GROUP_ID} /* MoleUI */,
				{PRODUCTS_GRP} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{SRC_GROUP_ID} /* MoleUI */ = {{
			isa = PBXGroup;
			children = (
{group_children()}
			);
			path = "MoleUI";
			sourceTree = "<group>";
		}};
		{PRODUCTS_GRP} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{PRODUCT_REF} /* MoleUI.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{TARGET} /* MoleUI */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {TARG_CFG_LIST} /* Build configuration list for PBXNativeTarget "MoleUI" */;
			buildPhases = (
				{SOURCES_PH} /* Sources */,
				{FRAMEWORKS_PH} /* Frameworks */,
				{RESOURCES_PH} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "MoleUI";
			productName = "MoleUI";
			productReference = {PRODUCT_REF} /* MoleUI.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJECT} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2600;
				LastUpgradeCheck = 2600;
				TargetAttributes = {{
					{TARGET} = {{
						CreatedOnToolsVersion = 26.0;
					}};
				}};
			}};
			buildConfigurationList = {PROJ_CFG_LIST} /* Build configuration list for PBXProject "MoleUI" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {MAIN_GROUP};
			productRefGroup = {PRODUCTS_GRP} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{TARGET} /* MoleUI */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{RESOURCES_PH} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{f'				{ASSETS_BUILD} /* Assets.xcassets in Resources */,' if has_assets else ''}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{SOURCES_PH} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_phase_files()}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{PROJ_DEBUG} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{PROJ_RELEASE} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			}};
			name = Release;
		}};
		{TARG_DEBUG} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{COMMON_BUILD}
			}};
			name = Debug;
		}};
		{TARG_RELEASE} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{COMMON_BUILD}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{PROJ_CFG_LIST} /* Build configuration list for PBXProject "MoleUI" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{PROJ_DEBUG} /* Debug */,
				{PROJ_RELEASE} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{TARG_CFG_LIST} /* Build configuration list for PBXNativeTarget "MoleUI" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{TARG_DEBUG} /* Debug */,
				{TARG_RELEASE} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {PROJECT} /* Project object */;
}}
"""

out_dir = os.path.join(ROOT, "MoleUI.xcodeproj")
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "project.pbxproj"), "w") as f:
    f.write(pbx)
print(f"Wrote project.pbxproj with {len(swift)} swift files:")
for s in swift:
    print("  ", s)
