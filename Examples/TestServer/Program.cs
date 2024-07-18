﻿using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;

namespace TestServer
{
    public class Program
    {
        public static void Main(string[] args) =>
            WebHost.CreateDefaultBuilder(args)
                .ConfigureLogging(factory =>
                {
                    factory.AddConsole()
                        .SetMinimumLevel(LogLevel.Debug);
                })
                .UseStartup<Startup>()
                .UseUrls("http://192.168.1.128:5000/")
                .Build()
                .Run();
    }
}
