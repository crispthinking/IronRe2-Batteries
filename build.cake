
var target = Argument("target", "Default");

public class Settings
{
  public string DylibExt {get; set;}
  public string Rid {get; set;}
  public string DylibPrefix {get; set;}
};

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

Task("BuildRe2")
  .Does(() =>
  {
    // TODO: Need to chose a different build path for Windows.
    var args = new ProcessArgumentBuilder()
      .Append("obj/libre2.a")
      .Append($"-j{Environment.ProcessorCount * 2}");

    StartProcess("make", new ProcessSettings {
      Arguments = args,
      WorkingDirectory = Directory("thirdparty/re2/"),
    });
  });

Task("BuildCre2")
  .IsDependentOn("BuildRe2")
  .Does<Settings>(s =>
  {
    var outFile = MakeAbsolute(File($"bin/contents/runtimes/{s.Rid}/native/{s.DylibPrefix}cre2.{s.DylibExt}"));
    CreateDirectory(outFile.GetDirectory());
    
    // TODO: we will need a different way to compile this on Windows
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
      .Append("src/cre2.cpp")
      .Append("../re2/obj/libre2.a")
      // output to our `bin/` folder
      .Append($"-o{outFile}");

    StartProcess("clang++", new ProcessSettings {
      Arguments = args,
      WorkingDirectory = Directory("thirdparty/cre2/"),
    });
  });

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

Task("Default")
    .Does(() =>
    {
        Information("hello world");
    });

RunTarget(target);
