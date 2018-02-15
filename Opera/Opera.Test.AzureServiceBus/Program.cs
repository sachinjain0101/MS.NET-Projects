using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.ServiceBus;
using Microsoft.Azure.ServiceBus.Core;

namespace Opera.Test.AzureServiceBus
{

    using System;
    using System.IO;
    using System.Text;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Azure.ServiceBus;
    using Microsoft.Azure.ServiceBus.Core;
    using Newtonsoft.Json;

    public class Program  {

        private static string connectionString = "Endpoint=sb://peoplenetqa.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GpBG4e9yHWnHa9zv/Yks5tbU55Y8QdOEtpvC8E/EGUI=";
        private static string PartitionedQueueName = "assignment";


        static async Task SendMessagesAsync(string connectionString, string queueName) {
            var sender = new MessageSender(connectionString, queueName);


            dynamic data = new[]
            {
                new {name = "Einstein", firstName = "Albert"},
                new {name = "Heisenberg", firstName = "Werner"},
                new {name = "Curie", firstName = "Marie"},
                new {name = "Hawking", firstName = "Steven"},
                new {name = "Newton", firstName = "Isaac"},
                new {name = "Bohr", firstName = "Niels"},
                new {name = "Faraday", firstName = "Michael"},
                new {name = "Galilei", firstName = "Galileo"},
                new {name = "Kepler", firstName = "Johannes"},
                new {name = "Kopernikus", firstName = "Nikolaus"}
            };

            for (int j = 0; j < 5; j++)
                for (int i = 0; i < data.Length; i++) {
                    var message = new Message(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(data[i]))) {
                        ContentType = "application/json",
                        Label = "Scientist",
                        MessageId = (i + j * data.Length).ToString(),
                        //TimeToLive = TimeSpan.FromMinutes(2),
                        PartitionKey = data[i].name.Substring(0, 1)
                    };

                    await sender.SendAsync(message);
                    lock (Console.Out) {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        Console.WriteLine("Message sent: Id = {0}", message.MessageId);
                        Console.ResetColor();
                    }
                }
        }

        static  async Task ReceiveMessagesAsync(string connectionString, string queueName, CancellationToken cancellationToken) {
            var doneReceiving = new TaskCompletionSource<bool>();
            var receiver = new MessageReceiver(connectionString, queueName, ReceiveMode.PeekLock);

            // close the receiver and factory when the CancellationToken fires 
            cancellationToken.Register(
                async () => {
                    await receiver.CloseAsync();
                    doneReceiving.SetResult(true);
                });

            // register the RegisterMessageHandler callback
            receiver.RegisterMessageHandler(
                async (message, cancellationToken1) => {
                    if (message.Label != null &&
                        message.ContentType != null &&
                        message.Label.Equals("Scientist", StringComparison.InvariantCultureIgnoreCase) &&
                        message.ContentType.Equals("application/json", StringComparison.InvariantCultureIgnoreCase)) {
                        var body = message.Body;

                        dynamic scientist = JsonConvert.DeserializeObject(Encoding.UTF8.GetString(body));
                        lock (Console.Out) {
                            Console.ForegroundColor = ConsoleColor.Cyan;
                            Console.WriteLine(
                                "\t\t\t\tMessage received: \n\t\t\t\t\t\tMessageId = {0}, \n\t\t\t\t\t\tSequenceNumber = {1:x}, \n\t\t\t\t\t\tEnqueuedTimeUtc = {2}," +
                                "\n\t\t\t\t\t\tExpiresAtUtc = {5}, \n\t\t\t\t\t\tContentType = \"{3}\", \n\t\t\t\t\t\tSize = {4},  \n\t\t\t\t\t\tContent: [ firstName = {6}, name = {7} ]",
                                message.MessageId,
                                message.SystemProperties.SequenceNumber,
                                message.SystemProperties.EnqueuedTimeUtc,
                                message.ContentType,
                                message.Size,
                                message.ExpiresAtUtc,
                                scientist.firstName,
                                scientist.name);
                            Console.ResetColor();
                        }
                        await receiver.CompleteAsync(message.SystemProperties.LockToken);
                    } else {
                        await receiver.DeadLetterAsync(message.SystemProperties.LockToken); //, "ProcessingError", "Don't know what to do with this message");
                    }
                },
                new MessageHandlerOptions((e) => LogMessageHandlerException(e)) { AutoComplete = false, MaxConcurrentCalls = 1 });

            await doneReceiving.Task;
        }

        private static  Task LogMessageHandlerException(ExceptionReceivedEventArgs e) {
            Console.WriteLine("Exception: \"{0}\" {0}", e.Exception.Message, e.ExceptionReceivedContext.EntityPath);
            return Task.CompletedTask;
        }

        public static void Main(string[] args) {
        MainAsync(args).GetAwaiter().GetResult();
        }


        public static async Task<int> MainAsync(string[] args) {
            try {
                Console.WriteLine("Press any key to exit the scenario");


                var cts = new CancellationTokenSource();

                await SendMessagesAsync(connectionString, PartitionedQueueName);
                var receiveTask = ReceiveMessagesAsync(connectionString, PartitionedQueueName, cts.Token);

                Task.WaitAny(
                    Task.Run(() => Console.ReadKey()),
                    Task.Delay(TimeSpan.FromSeconds(10)));

                cts.Cancel();

                await receiveTask;
            } catch (Exception e) {
                Console.WriteLine(e.ToString());
                return 1;
            }
            return 0;
        }
    }



    //public class Program {
    //    private static IQueueClient queueClient;
    //    private const string ServiceBusConnectionString = "Endpoint=sb://peoplenetqa.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GpBG4e9yHWnHa9zv/Yks5tbU55Y8QdOEtpvC8E/EGUI=";
    //    private const string QueueName = "assignment";

    //    public static void Main(string[] args) {
    //        MainAsync(args).GetAwaiter().GetResult();

    //    }

    //    private static async Task MainAsync(string[] args) {
    //        queueClient = new QueueClient(ServiceBusConnectionString, QueueName, ReceiveMode.PeekLock);

    //        //await SendMessagesToQueue(1);

    //        await ReceiveMessagesAsync(ServiceBusConnectionString, QueueName);


    //            // Close the client after the ReceiveMessages method has exited.
    //            await queueClient.CloseAsync();

    //        Console.WriteLine("Press any key to exit.");
    //        Console.ReadLine();
    //    }

    //    // Creates a Queue client and sends 10 messages to the queue.
    //    private static async Task SendMessagesToQueue(int numMessagesToSend) {



    //        for (var i = 0; i < numMessagesToSend; i++) {
    //            try {
    //                // Create a new brokered message to send to the queue

    //                List<Message> lst = new List<Message>();

    //                string str = "";
    //                for (int j = 1; j <= 2400; j++) {
    //                    str+= "a";
    //                }

    //                var m1 = new Message(Encoding.UTF8.GetBytes(str)) {
    //                    //ContentType = "application/json",
    //                    Label = "Scientist",
    //                    MessageId = "1",
    //                    //TimeToLive = TimeSpan.FromMinutes(2),
    //                    PartitionKey = "Y"
    //                };

    //                lst.Add(m1);
    //                await queueClient.SendAsync(m1);

    //                str = "";
    //                for (int j = 1; j <= 2400; j++) {
    //                    str += "b";
    //                }

    //                var m2 = new Message(Encoding.UTF8.GetBytes(str)) {
    //                    //ContentType = "string",
    //                    Label = "Scientist",
    //                    MessageId = "1",
    //                    //TimeToLive = TimeSpan.FromMinutes(2),
    //                    PartitionKey = "Y"
    //                };

    //                lst.Add(m2);


    //                // Write the body of the message to the console
    //                Console.WriteLine($"Sending message: xx ");

    //                // Send the message to the queue
    //                await queueClient.SendAsync(m2);

    //            } catch (Exception exception) {
    //                Console.WriteLine($"{DateTime.Now} > Exception: {exception.Message}");
    //            }

    //            // Delay by 10 milliseconds so that the console can keep up await Task.Delay(10);
    //        }

    //        Console.WriteLine($"{numMessagesToSend} messages sent.");
    //    }

    //    private static async Task ReceiveMessagesAsync(string connectionString, string queueName) {
    //        var doneReceiving = new TaskCompletionSource<bool>();
    //        var receiver = new MessageReceiver(connectionString, queueName, ReceiveMode.PeekLock);

    //        // register the RegisterMessageHandler callback

    //        receiver.RegisterMessageHandler(
    //                if (message.Label != null &&
    //                    message.ContentType != null &&
    //                    message.Label.Equals("Scientist", StringComparison.InvariantCultureIgnoreCase)
    //                    //message.ContentType.Equals("application/json", StringComparison.InvariantCultureIgnoreCase)
    //                    ) {
    //                    var body = message.Body;

    //                    await receiver.CompleteAsync(message.SystemProperties.LockToken);

    //                    Console.WriteLine(body);
    //                } else {
    //                    await receiver.DeadLetterAsync(message.SystemProperties.LockToken); //, "ProcessingError", "Don't know what to do with this message");
    //                }
    //            });

    //        await doneReceiving.Task;
    //    }

    //    private static Task LogMessageHandlerException(ExceptionReceivedEventArgs e) {
    //        Console.WriteLine("Exception: \"{0}\" {0}", e.Exception.Message, e.ExceptionReceivedContext.EntityPath);
    //        return Task.CompletedTask;
    //    }


    //}
}
