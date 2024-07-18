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
            Clients.All.SendAsync("NewMessage", new MessageData("Server msg", RandomString(8)));
            // repeateMessage(() => {  }, 5, cts.Token);
            // }

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