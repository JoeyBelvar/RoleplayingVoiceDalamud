using System.Reflection;
using System.Runtime.Loader;

var payloadPath = Environment.GetEnvironmentVariable("ARTEMIS_RELAY_PAYLOAD_PATH") ?? "/mnt/mounted_folders/Artemis Dialogue Server";
var entryAssembly = Environment.GetEnvironmentVariable("ARTEMIS_RELAY_ENTRY_ASSEMBLY") ?? "CachedTTSRelay.dll";
var enabledServices = (Environment.GetEnvironmentVariable("ARTEMIS_RELAY_SERVICES") ?? "audio,information,server-list")
    .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
    .Select(static service => service.ToLowerInvariant())
    .ToHashSet(StringComparer.OrdinalIgnoreCase);

Console.WriteLine($"[artemis-relay-shim] payload={payloadPath}");
Console.WriteLine($"[artemis-relay-shim] entry={entryAssembly}");
Console.WriteLine($"[artemis-relay-shim] services={string.Join(',', enabledServices)}");

if (!Directory.Exists(payloadPath))
{
    Console.Error.WriteLine($"[artemis-relay-shim] payload directory does not exist: {payloadPath}");
    return 66;
}

var entryPath = Path.Combine(payloadPath, entryAssembly);
if (!File.Exists(entryPath))
{
    Console.Error.WriteLine($"[artemis-relay-shim] relay assembly does not exist: {entryPath}");
    return 66;
}

Directory.SetCurrentDirectory(payloadPath);
AssemblyLoadContext.Default.Resolving += (_, name) =>
{
    var payloadAssembly = Path.Combine(payloadPath, $"{name.Name}.dll");
    if (File.Exists(payloadAssembly))
    {
        Console.WriteLine($"[artemis-relay-shim] loading {name.Name} from payload");
        return AssemblyLoadContext.Default.LoadFromAssemblyPath(payloadAssembly);
    }

    return null;
};

var assembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(entryPath);
var programType = assembly.GetType("CachedTTSRelay.Program", throwOnError: true)!;

if (enabledServices.Contains("audio"))
{
    Invoke(programType, "StartAudioRelay");
}

if (enabledServices.Contains("information"))
{
    Invoke(programType, "StartInformationService");
}

if (enabledServices.Contains("server-list"))
{
    Invoke(programType, "StartServerListService");
}

Console.WriteLine("[artemis-relay-shim] relay services requested; waiting indefinitely");
await Task.Delay(Timeout.InfiniteTimeSpan);
return 0;

static void Invoke(Type programType, string methodName)
{
    var method = programType.GetMethod(methodName, BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic)
        ?? throw new MissingMethodException(programType.FullName, methodName);

    Console.WriteLine($"[artemis-relay-shim] invoking {methodName}");
    method.Invoke(null, Array.Empty<object>());
}
