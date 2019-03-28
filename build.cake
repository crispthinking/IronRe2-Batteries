
var target = Argument("target", "Default");

public class Settings
{
  public string DylibExt {get; set;}
};

Setup<Settings>(context =>
{
  switch (context.Environment.Platform.Family)
  {
      case PlatformFamily.Linux:
        return new Settings {
          DylibExt = "so"
        };
      case PlatformFamily.OSX:
        return new Settings {
          DylibExt = "dylib"
        };
      case PlatformFamily.Windows:
        return new Settings {
          DylibExt = "dll"
        };
      default:
        throw new Exception("Unknown platform!");
  }
});

Task("BuildRe2")
  .Does(() =>
  {
    // TODO: Need to chose a different build path for Windows.
    // TODO: We can optimise this by using more threads with (-j)
    // TODO: we can optimise this by only building the static library
    StartProcess("make", new ProcessSettings {
      Arguments = "",
      WorkingDirectory = Directory("thirdparty/re2/"),
    });
  });

Task("BuildCre2")
  .IsDependentOn("BuildRe2")
  .Does<Settings>(s =>
  {
    var outFile = MakeAbsolute(File($"bin/libcre2.{s.DylibExt}"));
    CreateDirectory(outFile.GetDirectory());
    Information("Building with Clang++");
    Information(outFile);
    
    // TODO: we will need a different way to compile this on Windows

    // To compile CRE2 we shell out to `clang++` directly. It's only a single
    // C++ file. We statically link in the RE2 build we produced earlier in
    // the `BuildRe2` task.
    var args = new ProcessArgumentBuilder()
      // we're building a shared library
      .Append("-shared")
      .Append("-fpic")
      // Uses C++ 11
      .Append("-std=c++11")
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

Task("Default")
    .Does(() =>
    {
        Information("hello world");
    });

RunTarget(target);
