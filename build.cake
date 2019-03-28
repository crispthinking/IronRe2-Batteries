
var target = Argument("target", "Default");

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

Task("Default")
    .Does(() =>
    {
        Information("hello world");
    });

RunTarget(target);
