using System;
using System.Linq;
using Mono.Cecil;
using Mono.Cecil.Cil;

class Program
{
    static int Main(string[] args)
    {
        string[] paths = (args != null && args.Length > 0)
            ? args
            : new string[] {
                @"C:\Program Files\Rhino 9 WIP\System\RhinoGreet.dll",
                @"C:\Program Files\Rhino 9 WIP\System\netcore\RhinoGreet.dll"
            };

        foreach (var path in paths)
        {
            Console.WriteLine("Reading " + path);
            var asm = AssemblyDefinition.ReadAssembly(path, new ReaderParameters { ReadWrite = true });

            var greetType = asm.MainModule.GetType("RhinoGreet.RhinoGreet");
            var modelType = asm.MainModule.GetType("RhinoGreet.RhinoGreetModel");

            // 1. Patch CanAutoHideNow -> return false
            var canAutoHide = greetType.Methods.First(m => m.Name == "CanAutoHideNow");
            Console.WriteLine("Found method " + canAutoHide.FullName);
            canAutoHide.Body.Instructions.Clear();
            canAutoHide.Body.Variables.Clear();
            canAutoHide.Body.ExceptionHandlers.Clear();
            var il1 = canAutoHide.Body.GetILProcessor();
            canAutoHide.Body.Instructions.Add(il1.Create(OpCodes.Ldc_I4_0));
            canAutoHide.Body.Instructions.Add(il1.Create(OpCodes.Ret));

            // 2. Patch OnSkinHideSplash -> return immediately (do not dismiss greet on splash hide)
            var onHideSplash = modelType.Methods.First(m => m.Name == "OnSkinHideSplash");
            Console.WriteLine("Found method " + onHideSplash.FullName);
            onHideSplash.Body.Instructions.Clear();
            onHideSplash.Body.Variables.Clear();
            onHideSplash.Body.ExceptionHandlers.Clear();
            var il2 = onHideSplash.Body.GetILProcessor();
            onHideSplash.Body.Instructions.Add(il2.Create(OpCodes.Ret));

            Console.WriteLine("Writing back patched assembly...");
            asm.Write();
            Console.WriteLine("Patched successfully: " + path);
        }
        return 0;
    }
}
