
var target = Argument("target", "Default");


Task("Default")
    .Does(() =>
    {
        Information("hello world");
    });

RunTarget(target);