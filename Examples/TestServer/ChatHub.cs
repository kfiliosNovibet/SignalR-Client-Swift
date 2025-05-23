using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR;

public class MessageData
{
    public string user { get; set; }
    public string message { get; set; }

    public MessageData(string user, string message)
    {
        this.user = user;
        this.message = message;
    }
}

namespace TestServer
{
    public class ChatHub : Hub
    {
        private Boolean hasAlreadyStartRT = false;
        private CancellationTokenSource cts = new CancellationTokenSource();
        private Random random = new Random();
        private Task repeat;

        public Task Broadcast(string sender, string message)
        {
            if (message == "abort")
            {
                Context.Abort();
                return Task.CompletedTask;
            }

            // if (!hasAlreadyStartRT)
            // {
            hasAlreadyStartRT = true;
            for (int i = 1; i <= 1000000000000; i++)
            {
                MessageData messageData = new MessageData("Server msg", RandomString(8));
                Console.WriteLine(messageData);
                Clients.All.SendAsync("NewMessage", messageData);
                Thread.Sleep(500);
            }
            // Clients.All.SendAsync("NewMessage", new MessageData("Server msg", "{\"type\":7,\"error\":\"Connection closed with an error.\",\"allowReconnect\":true}"));
            // repeateMessage(() => {  }, 5, cts.Token);
            // }
            
            // Thread thread = new Thread(() =>
            // {
            //     Thread.Sleep(2000);
            //     Clients.All.
            //     Console.WriteLine("Thread running separately.");
            // });

            // thread.Start();

            return Clients.All.SendAsync("NewMessage", sender, message);
        }

        private void repeateMessage(Action action, int seconds, CancellationToken token)
        {
            if (action == null)
                return;
            repeat = Task.Run(async () =>
            {
                while (!token.IsCancellationRequested)
                {
                    action();
                    await Task.Delay(TimeSpan.FromSeconds(seconds), token);
                }
            }, token);
        }

        private string RandomString(int length)
        {
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            return new string(Enumerable.Repeat(chars, length)
                .Select(s => s[random.Next(s.Length)]).ToArray());
        }
    }
}