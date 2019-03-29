#tool nuget:?package=GitVersion.CommandLine&version=4.0.0
#addin nuget:?package=Cake.CMake&version=0.2.2

var target = Argument("target", "Default");

// Used for copyright and ownership information.
public const string CrispGroupName = "Crisp Thinking Group Ltd.";

public class Settings
{
  public string DylibExt {get; set;}
  public string Rid {get; set;}
  public string DylibPrefix {get; set;}
};

public void Check(int exitCode)
{
  if (exitCode != 0)
    throw new Exception($"Process returned non-zero exit code '{exitCode}'");
}

// Cached settings for the current platform
Setup<Settings>(context =>
{
  switch (context.Environment.Platform.Family)
  {
      case PlatformFamily.Linux:
        return new Settings {
          DylibExt = "so",
          DylibPrefix = "lib",
          Rid = "linux-x64",
        };
      case PlatformFamily.OSX:
        return new Settings {
          DylibExt = "dylib",
          DylibPrefix = "lib",
          Rid = "osx-x64",
        };
      case PlatformFamily.Windows:
        return new Settings {
          DylibExt = "dll",
          DylibPrefix = string.Empty,
          Rid = "win-x64",
        };
      default:
        throw new Exception("Unknown platform!");
  }
});

// Build the RE2 library
Task("BuildRe2")
  .Does(() =>
  {
    if (Context.Environment.Platform.IsUnix())
    {
      var args = new ProcessArgumentBuilder()
        .Append("obj/libre2.a")
        .Append($"-j{Environment.ProcessorCount * 2}");

      Check(StartProcess("make", new ProcessSettings {
        Arguments = args,
        WorkingDirectory = Directory("thirdparty/re2/"),
      }));
    }
    else
    {
      CreateDirectory("bin/re2/");
      CMake("thirdparty/re2/", new CMakeSettings {
        OutputPath = "bin/re2/",
        Options = new [] { "-DBUILD_TESTING=OFF", "-DBUILD_SHARED_LIBS=OFF", "-DRE2_BUILD_TESTING=OFF", "-DCMAKE_GENERATOR_PLATFORM=x64" },
      });
      MSBuild("bin/re2/RE2.sln", new MSBuildSettings {
        Verbosity = Verbosity.Minimal,
        Configuration = "Release",
      });
    }
  });

// Build the C FFI interface and link in RE2 statically
Task("BuildCre2")
  .IsDependentOn("BuildRe2")
  .Does<Settings>(s =>
  {
    var outFile = MakeAbsolute(File($"bin/contents/runtimes/{s.Rid}/native/{s.DylibPrefix}cre2.{s.DylibExt}"));
    CreateDirectory(outFile.GetDirectory());
    
    // For this build we just shell out to the platform's C++ compiler
    if (Context.Environment.Platform.IsUnix())
    {
      Information("Building with Clang++");
      Information(outFile);
      
      // To compile CRE2 we shell out to `clang++` directly. It's only a single
      // C++ file. We statically link in the RE2 build we produced earlier in
      // the `BuildRe2` task.
      var args = new ProcessArgumentBuilder()
        // we're building a shared library
        .Append("-shared")
        .Append("-fpic")
        // Uses C++ 11
        .Append("-std=c++11")
        // Release build please
        .Append("-O3")
        .Append("-g")
        .Append("-DNDEBUG")
        // Need to define the version number for the library
        .Append("-Dcre2_VERSION_INTERFACE_CURRENT=0")
        .Append("-Dcre2_VERSION_INTERFACE_REVISION=0")
        .Append("-Dcre2_VERSION_INTERFACE_AGE=0")
        .Append("-Dcre2_VERSION_INTERFACE_STRING=\\\"0.0.0\\\"")
        // sources and static libraries to link in
        .Append("-I../re2/")
        .Append("-L../re2/obj/")
        .Append("-lre2")
        .Append("src/cre2.cpp")
        // output to our `bin/` folder
        .Append($"-o{outFile}");

      Check(StartProcess("clang++", new ProcessSettings {
        Arguments = args,
        WorkingDirectory = Directory("thirdparty/cre2/"),
      }));
    }
    else
    {
      var args = new ProcessArgumentBuilder()
        // C++ 14 dynamic library with exceptions
        .Append("/EHsc")
        .Append("/std:c++14")
        .Append("/LD")
        .Append("/MD")
        // Release build
        .Append("/O2")
        .Append("/DNDEBUG")
        // Need to define the version number for the library
        .Append("/Dcre2_VERSION_INTERFACE_CURRENT=0")
        .Append("/Dcre2_VERSION_INTERFACE_REVISION=0")
        .Append("/Dcre2_VERSION_INTERFACE_AGE=0")
        .Append("/Dcre2_VERSION_INTERFACE_STRING=\\\"0.0.0\\\"")
        // sources to use and location of object files
        .Append("/I../re2/")
        .Append("src/cre2.cpp")
        .Append("/Fo.\\..\\..\\bin")
        // Linker options. Include the RE2 static library and set the output
        .Append("/link")
        .Append("../../bin/re2/Release/re2.lib")
        .Append($"/out:{outFile}");
      Check(StartProcess("cl", new ProcessSettings {
        Arguments = args,
        WorkingDirectory = Directory("thirdparty/cre2/"),
      }));
    }
  });

// Create the NuGet battery pack package for this platform 
Task("Pack")
  .IsDependentOn("BuildCre2")
  .Does(() =>
  {
    CreateDirectory("bin/artifacts/");
    var versionInfo = GitVersion(new GitVersionSettings
    {
      UpdateAssemblyInfo = false,
      NoFetch = true,
    });
    NuGetPack(new NuGetPackSettings {
      Id                      = $"IronRe2-Batteries.{Context.Environment.Platform.Family}",
      Version                 = versionInfo.NuGetVersionV2,
      Title                   = "IronRe2 Batteries",
      Authors                 = new[] { CrispGroupName },
      Owners                  = new[] { CrispGroupName },
      Description             = "platform-specific Nu-Get package containing RE2 and the cre2 wrapper",
      Summary                 = "Native code dependency of IronRe2",
      ProjectUrl              = new Uri("https://github.com/crispthinking/IronRe2-Batteries/"),
      LicenseUrl              = new Uri("https://github.com/crispthinking/IronRe2-Batteries/blob/master/LICENSE"),
      Copyright               = $"{CrispGroupName} 2019",
      Tags                    = new [] {"Regex", "Re2"},
      RequireLicenseAcceptance= false,
      Symbols                 = false,
      NoPackageAnalysis       = true,
      Files                   = new [] {
        new NuSpecContent {Source = "bin/contents/", Target = ""},
      },
      BasePath                = "./",
      OutputDirectory         = "bin/artifacts/"
    });
  });

// Remove the build artifacts and clean the thirdparty repos
Task("Clean")
  .Does(() =>
  {
    DeleteDirectory("bin/", new DeleteDirectorySettings {
      Recursive = true,
      Force = true
    });
    StartProcess("make", new ProcessSettings {
      Arguments = "clean",
      WorkingDirectory = Directory("thirdparty/re2/"),
    });
  });

// Phony target to trigger all the things we _usually_ want done.
Task("Default")
  .IsDependentOn("Pack");

RunTarget(target);
